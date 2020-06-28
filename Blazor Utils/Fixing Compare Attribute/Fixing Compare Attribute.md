## Blazor Utils Tutorial - Fixing Compare Attribute:

To fix the issues with compare attribute we have to add the following code to our project:
   
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








