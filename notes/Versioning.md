### Version Format
- **Marketing Version**: `YYYY.M` (Year.Month format)
- **Build Number**: unique integer number (based on git head count)


#### Version Management
- **Tool** Uses Apple's `agvtool` for marketing versions.
- **Build Numbers**: Automatically store 'git rev-list --count HEAD' during the build process in the bundle 
- **Beta Releases**: Clear distinction with "beta" suffix in marketing version