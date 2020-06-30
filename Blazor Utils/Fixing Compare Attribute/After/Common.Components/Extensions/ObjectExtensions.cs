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