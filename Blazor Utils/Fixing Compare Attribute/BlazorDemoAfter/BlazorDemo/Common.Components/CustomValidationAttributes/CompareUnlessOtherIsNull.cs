using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Text;
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
