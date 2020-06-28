## Blazor Utils Tutorial - Fixing Compare Attribute:

To fix the issues with `Compare Attribute` we have to add the following files to our project to our project:
   
`CommonLibrary\Extensions\ObjectExtensions.cs`

```c#
using System.ComponentModel;
using System.Linq;

namespace CommonLibrary.Extensions
{
    public static class ObjectExtensions
    {
        public static string GetDisplayName(this object model, string propName) 
            => ((DisplayNameAttribute)model.GetType().GetProperty(propName)?.GetCustomAttributes(typeof(DisplayNameAttribute), true)
                .SingleOrDefault())?.DisplayName ?? propName;
    }
}
```

`CommonLibrary\CustomValidationAttributes\CompareUnlessOtherIsNull.cs`

```c#
using System;
using System.ComponentModel.DataAnnotations;
using CommonLibrary.Extensions;

namespace CommonLibrary.CustomValidationAttributes
{
    public class ComparePropertyUnlessOtherIsNull : ValidationAttribute
    {
        public string OtherPropertyName { get; set; }

        public ComparePropertyUnlessOtherIsNull(string otherPropertyName)
        {
            OtherPropertyName = otherPropertyName;
        }

        protected override ValidationResult IsValid(object value, ValidationContext vc)
        {
            var pi = vc.ObjectType.GetProperty(OtherPropertyName);
            if (pi == null)
                throw new NullReferenceException("There is no property with the specified name");

            var model = vc.ObjectInstance;
            var otherPropertyValue = pi.GetValue(model);

            return value == null || otherPropertyValue == null || value.Equals(otherPropertyValue) 
                ? ValidationResult.Success : new ValidationResult(GetErrorMessage(model, vc), new[] { vc.MemberName });
        }

        public string GetErrorMessage(object model, ValidationContext vc) => ErrorMessage 
             ?? $"'{model.GetDisplayName(vc.MemberName)}' must match '{model.GetDisplayName(OtherPropertyName)}'";
    }
}
```

`CommonLibrary\Components\CustomDataAnnotationsValidator.razor`

```razor
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Reflection;
using CommonLibrary.CustomValidationAttributes;
using CommonLibrary.Extensions;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Forms;

namespace CommonLibrary.Components
{
    public class CustomDataAnnotationsValidator : ComponentBase
    {
        private ValidationMessageStore _messageStore;

        [CascadingParameter] 
        public EditContext CurrentEditContext { get; set; }

        protected override void OnInitialized()
        {
            if (CurrentEditContext == null)
                throw new InvalidOperationException(
                    $"{nameof(DataAnnotationsValidator)} requires a cascading parameter of type {nameof(EditContext)}");

            CurrentEditContext.OnFieldChanged += CurrentEditContext_FieldChanged;
            CurrentEditContext.OnValidationRequested += CurrentEditContext_ValidationRequested;
            _messageStore = new ValidationMessageStore(CurrentEditContext);
        }

        private void CurrentEditContext_ValidationRequested(object sender, ValidationRequestedEventArgs e) => ValidateModel();
        private void CurrentEditContext_FieldChanged(object sender, FieldChangedEventArgs e) => ValidateField(e.FieldIdentifier);

        private void ValidateField(FieldIdentifier fieldIdentifier)
        {
            var model = fieldIdentifier.Model;
            var allProperties = model.GetType().GetProperties();
            var previousValidationMessages = allProperties.ToDictionary(
                p => p.Name, p => CurrentEditContext.GetValidationMessages(new FieldIdentifier(model, p.Name)).ToArray());

            _messageStore.Clear();

            foreach (var prop in allProperties)
            {
                var vrs = new List<ValidationResult>();
                var vc = new ValidationContext(model) { MemberName = prop.Name };
                var fi = new FieldIdentifier(model, prop.Name);
                var compareAttr = GetCompareAttrOrNull(prop);

                if (prop.Name == fieldIdentifier.FieldName)
                {
                    if (!Validator.TryValidateProperty(prop.GetValue(model), vc, vrs))
                        _messageStore.Add(fi, vrs.Select(r => r.ErrorMessage));
                }
                else if (compareAttr != null && compareAttr.OtherPropertyName == fieldIdentifier.FieldName)
                {
                    _messageStore.Add(fieldIdentifier, previousValidationMessages[prop.Name].Where(vm 
                        => !vm.EqualsInvariant(compareAttr.GetErrorMessage(model, vc))).ToArray());
                    if (!Validator.TryValidateValue(prop.GetValue(model), vc, vrs, new[] { compareAttr }))
                        _messageStore.Add(fi, vrs.Select(r => r.ErrorMessage));
                }
                else
                {
                    _messageStore.Add(fi, previousValidationMessages[prop.Name]);
                }
            }

            CurrentEditContext.NotifyValidationStateChanged();
        }

        private void ValidateModel()
        {
            var model = CurrentEditContext.Model;
            var vc = new ValidationContext(model);
            var vrs = new List<ValidationResult>();
            _messageStore.Clear();

            Validator.TryValidateObject(model, vc, vrs, true);

            foreach (var vr in vrs)
            {
                if (!vr.MemberNames.Any())
                    _messageStore.Add(new FieldIdentifier(model, string.Empty), vr.ErrorMessage);
                else
                    foreach (var mn in vr.MemberNames)
                        _messageStore.Add(new FieldIdentifier(model, mn), vr.ErrorMessage);
            }

            CurrentEditContext.NotifyValidationStateChanged();
        }

        private static ComparePropertyUnlessOtherIsNull GetCompareAttrOrNull(ICustomAttributeProvider pi)
            => pi.GetCustomAttributes(true).SingleOrDefault(a => a is ComparePropertyUnlessOtherIsNull) as ComparePropertyUnlessOtherIsNull;
    }
}
```

We also have to modify two existing files:

`BlazorDemo/Models/EditEmployeeVM.cs`

```c#
using System;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using CommonLibrary.CustomValidationAttributes;

namespace BlazorDemo.Models
{
    public class EditEmployeeVM
    {
        public int Id { get; set; }

        [Required(ErrorMessage = "First name must be provided")]
        [MinLength(2)]
        public string FirstName { get; set; }

        [Required]
        public string LastName { get; set; }

        [EmailAddress]
        [EmailDomain(AllowedDomain = "test.com")]
        [DisplayName("Company Email")]
        public string Email { get; set; }

        [ComparePropertyUnlessOtherIsNull(nameof(Email))]
        [DisplayName("Confirm Company Email")]
        public string ConfirmEmail { get; set; }

        public DateTime DateOfBirth { get; set; }
        public Gender Gender { get; set; }
        public int DepartmentId { get; set; }
        public string PhotoPath { get; set; }

        [ValidateComplexType]
        public virtual Department Department { get; set; } = new Department();
    }
}
```

`BlazorDemo/Pages/EditEmployee.razor`

```razor
@page "/editemployee/{id}"
@page "/editemployee/"

@using BlazorDemo.Models
@using CommonLibrary.Extensions
@using RouteAttribute = Microsoft.AspNetCore.Components.RouteAttribute
@inherits EditEmployeeBase

<ConfirmationDialog @ref="DeleteConfirmation" ConfirmationChanged="BtnConfirmDelete_ClickAsync"
    ConfirmationMessage=@($"Are you sure you want to delete \"{EditEmployeeVM.FirstName}\"?")>
</ConfirmationDialog>

<div>
    <EditForm Model="EditEmployeeVM" OnValidSubmit="@EditForm_ValidSubmitAsync">
        <CustomDataAnnotationsValidator />
        <div class="row">
            <div class="col-12">
                <h3>@PageHeaderText</h3>
                <hr class="mt-10px" />
            </div>
        </div>
        <div class="row">
            <div class="col-12 d-none-if-empty">
                <ValidationSummary />
            </div>
        </div>
        <div class="row">
            <div class="col-xl-2 col-lg-3 col-sm-6 col-12">
                <label for="inputFirstName" class="col-form-label">First Name</label>
            </div>
            <div class="col-xl-3 col-lg-4 col-sm-6 col-12">
                <InputText @bind-Value="EditEmployeeVM.FirstName" id="inputFirstName" class="form-control" placeholder="First Name..." />
            </div>
            <div class="col-xl-7 col-lg-5 col-12 d-none-if-empty">
                <ValidationMessage For="@(() => EditEmployeeVM.FirstName)"></ValidationMessage>
            </div>
        </div>
        <div class="row">
            <div class="col-xl-2 col-lg-3 col-sm-6 col-12">
                <label for="inputLastName" class="col-form-label">Last Name</label>
            </div>
            <div class="col-xl-3 col-lg-4 col-sm-6 col-12">
                <InputText @bind-Value="EditEmployeeVM.LastName" id="inputLastName" class="form-control" placeholder="Last Name..." />
            </div>
            <div class="col-xl-7 col-lg-5 col-12 d-none-if-empty">
                <ValidationMessage For="@(() => EditEmployeeVM.LastName)"></ValidationMessage>
            </div>
        </div>
        <div class="row">
            <div class="col-xl-2 col-lg-3 col-sm-6 col-12">
                <label for="inputEmail" class="col-form-label">@EditEmployeeVM.GetDisplayName(nameof(EditEmployeeVM.Email))</label>
            </div>
            <div class="col-xl-3 col-lg-4 col-sm-6 col-12">
                <InputText @bind-Value="EditEmployeeVM.Email" id="inputEmail" class="form-control" placeholder="@($"{EditEmployeeVM.GetDisplayName(nameof(EditEmployeeVM.Email))}...")" />
            </div>
            <div class="col-xl-7 col-lg-5 col-12 d-none-if-empty">
                <ValidationMessage For="@(() => EditEmployeeVM.Email)"></ValidationMessage>
            </div>
        </div>
        <div class="row">
            <div class="col-xl-2 col-lg-3 col-sm-6 col-12">
                <label for="inputEmail" class="col-form-label">@EditEmployeeVM.GetDisplayName(nameof(EditEmployeeVM.ConfirmEmail))</label>
            </div>
            <div class="col-xl-3 col-lg-4 col-sm-6 col-12">
                <InputText @bind-Value="EditEmployeeVM.ConfirmEmail" id="inputEmail" class="form-control" placeholder="@($"{EditEmployeeVM.GetDisplayName(nameof(EditEmployeeVM.ConfirmEmail))}...")" />
            </div>
            <div class="col-xl-7 col-lg-5 col-12 d-none-if-empty">
                <ValidationMessage For="@(() => EditEmployeeVM.ConfirmEmail)"></ValidationMessage>
            </div>
        </div>
        <div class="row">
            <div class="col-xl-2 col-lg-3 col-sm-6 col-12">
                <label for="inputDepartment" class="col-form-label">Department</label>
            </div>
            <div class="col-xl-3 col-lg-4 col-sm-6 col-12">
                <CustomInputSelect @bind-Value="EditEmployeeVM.DepartmentId" id="inputDepartment" class="form-control" placeholder="Department...">
                    @foreach (var department in AvailableDepartments)
                    {
                        <option value="@department.Id">@department.Name</option>
                    }
                </CustomInputSelect>
            </div>
            <div class="col-xl-7 col-lg-5 col-12 d-none-if-empty">
                <ValidationMessage For="@(() => EditEmployeeVM.DepartmentId)"></ValidationMessage>
            </div>
        </div>
        <div class="row">
            <div class="col-xl-2 col-lg-3 col-sm-6 col-12">
                <label for="inputGender" class="col-form-label">Gender</label>
            </div>
            <div class="col-xl-3 col-lg-4 col-sm-6 col-12">
                <CustomInputSelect @bind-Value="EditEmployeeVM.Gender" id="inputGender" class="form-control" placeholder="Gender...">
                    @foreach (var gender in Enum.GetValues(typeof(Gender)))
                    {
                        <option value="@gender">@gender</option>
                    }
                </CustomInputSelect>
            </div>
            <div class="col-xl-7 col-lg-5 col-12 d-none-if-empty">
                <ValidationMessage For="@(() => EditEmployeeVM.Gender)"></ValidationMessage>
            </div>
        </div>
        <div class="row">
            <div class="col-xl-2 col-lg-3 col-sm-6 col-12">
                <label for="inputDateOfBirth" class="col-form-label">Date of Birth</label>
            </div>
            <div class="col-xl-3 col-lg-4 col-sm-6 col-12">
                <InputDate @bind-Value="EditEmployeeVM.DateOfBirth" id="inputDateOfBirth" class="form-control" placeholder="Date of Birth..."></InputDate>
            </div>
            <div class="col-xl-7 col-lg-5 col-12 d-none-if-empty">
                <ValidationMessage For="@(() => EditEmployeeVM.DateOfBirth)"></ValidationMessage>
            </div>
        </div>
        <div class="row">
            <div class="col-xl-1 col-lg-2 col-sm-4 col-12 offset-xl-2 offset-lg-3">
                <button class="btn btn-primary w-100" type="submit">Submit</button>
            </div>
            @if (EditEmployeeVM.Id > 0)
            {
                <div class="col-xl-1 col-lg-2 col-sm-4 col-12">
                    <button class="btn btn-danger w-100" type="button" @onclick="BtnDelete_Click">Delete</button>
                </div>
            }
        </div>
    </EditForm>
</div>

@code
{
    protected override void OnInitialized()
    {
        Routes.Clear();
        Routes.AddRange(GetType().GetCustomAttributes(typeof(RouteAttribute), true).Select(r => ((RouteAttribute)r).Template).ToArray());
    }
}
```










