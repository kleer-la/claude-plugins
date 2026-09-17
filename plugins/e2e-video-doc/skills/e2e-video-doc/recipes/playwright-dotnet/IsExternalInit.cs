// What a current C# compiler needs from the runtime and .NET Framework 4.8 does not ship:
// `init` accessors and positional records, which Capture.cs and ApiPanel.cs use. Compiled
// out on .NET 5+, where the runtime has it. Delete this file if your project already carries
// one — two definitions of the same type are an error.
#if !NET5_0_OR_GREATER
namespace System.Runtime.CompilerServices
{
	internal static class IsExternalInit
	{
	}
}
#endif
