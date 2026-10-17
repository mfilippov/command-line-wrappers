# Command-Line Wrappers for java, dotnet and uv commands
This repository contains cross-platform script wrappers for java, dotnet and uv tools. You could use it to run these tools on any OSes without installation.

## How to use:
Just copy ```java.cmd```, ```dotnet.cmd```, ```uv.cmd``` or ```uvx.cmd``` file into your project and run it.
## Example:
```./java.cmd --version```, ```./dotnet.cmd --version```, ```./uv.cmd --version``` or ```./uvx.cmd ruff --version```
## How to configure:
- You could change base dir name for temp folder to update **COMPANY_DIR** env var in scripts.
- You could change download url and destination folder name in variables: [**JVM_URL**, **JVM_TARGET_DIR**] for Java, [**DOTNET_URL**, **DOTNET_TARGET_DIR**] for dotnet and [**UV_URL**, **UV_TARGET_DIR**] for uv.
- ```uv.cmd``` and ```uvx.cmd``` share one download folder. ```uvx.cmd``` runs the ```uvx``` binary from the same archive.
Pay attention you need to update env in three places one per OS.
