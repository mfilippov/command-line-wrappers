# Command-Line Wrappers for java and dotnet command
This repository contains cross-platform script wrappers for java and dotnet tools. You could use it to run these tools on any OSes without installation.

## How to use:
Just copy ```java.cmd``` or ```dotnet.cmd``` file into your project and run it.
## Example:
```./java.cmd --version``` or ```./dotnet.cmd --version```
## How to configure:
- You could change base dir name for temp folder to update **COMPANY_DIR** env var in scripts.
- You could change download url and destination folder name in variables: [**JVM_URL**, **JVM_TARGET_DIR**] for Java and [**DOTNET_URL**, **DOTNET_TARGET_DIR**] for dotnet.
Pay attention you need to update env in three places one per OS.