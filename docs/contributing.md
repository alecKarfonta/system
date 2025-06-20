# Contributing Guidelines

Thank you for your interest in contributing to the ML Development Environment Setup project! This guide will help you get started.

## 🚀 Quick Start for Contributors

1. **Fork the repository** on GitHub
2. **Clone your fork** locally
3. **Create a feature branch** from `dev`
4. **Make your changes** following our standards
5. **Test your changes** thoroughly
6. **Submit a pull request** with a clear description

## 📋 Types of Contributions

### 🐛 Bug Reports
- Use the issue template
- Include system information (OS, versions)
- Provide clear reproduction steps
- Add relevant logs or error messages

### 💡 Feature Requests
- Explain the use case and benefits
- Consider backward compatibility
- Discuss implementation approach
- Check if it fits the project scope

### 📖 Documentation Improvements
- Fix typos, unclear instructions
- Add missing documentation
- Improve examples and tutorials
- Update outdated information

### 🔧 Code Contributions
- New component setup scripts
- Improvements to existing scripts
- Bug fixes and optimizations
- Test script additions

## 📁 Repository Structure

```
system/
├── docs/                    # Documentation (you're here!)
├── {component}/             # Component directories
│   ├── README.md           # Component documentation
│   ├── install.sh          # Installation script
│   ├── test.sh             # Testing script
│   └── configs/            # Configuration files
├── setup/                   # Main setup scripts
├── docker-compose.yml       # Multi-service setup
└── README.md               # Main documentation
```

## 📝 Documentation Standards

### Component Documentation
All components must follow the template in `docs/TEMPLATE.md`:

- **Overview**: What it does and why it's important
- **Quick Start**: Essential commands to get running
- **Installation**: Detailed setup instructions
- **Configuration**: Customization options
- **Testing**: Verification steps
- **Troubleshooting**: Common issues and solutions

### Writing Style
- **Clear and concise**: Avoid jargon, explain technical terms
- **Action-oriented**: Use imperative mood ("Install X", not "X should be installed")
- **Code examples**: Include working examples for all instructions
- **Error handling**: Document common failure modes and solutions

### Formatting
- Use consistent markdown formatting
- Include emoji headers for visual organization
- Code blocks must specify language for syntax highlighting
- Link to related components and external resources

## 🔧 Code Standards

### Script Requirements
Every component should have:
- `install.sh` - Automated installation
- `test.sh` - Validation and testing
- `README.md` - Following our template

### Script Standards
```bash
#!/bin/bash
# Brief description of what this script does

set -e  # Exit on any error
trap 'echo "Error occurred. Check the logs above."; exit 1' ERR

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}
```

### Error Handling
- Always use `set -e` for safety
- Provide meaningful error messages
- Include cleanup on failure where appropriate
- Test error conditions

### Configuration Management
- Use environment variables for customization
- Provide sensible defaults
- Document all configuration options
- Use `.example` files for templates

## 🧪 Testing Requirements

### Before Submitting
- [ ] Test on a clean Ubuntu 20.04+ system
- [ ] Test on macOS (if applicable)
- [ ] Verify all links in documentation work
- [ ] Run existing test scripts to ensure no regressions
- [ ] Test the complete setup flow

### Test Scripts
All components should include `test.sh` that:
- Verifies installation was successful
- Tests basic functionality
- Provides clear pass/fail output
- Cleans up temporary resources

Example test script structure:
```bash
#!/bin/bash
# Test script for {component}

set -e

echo "Testing {component} installation..."

# Test 1: Command exists
if command -v {command} >/dev/null 2>&1; then
    echo "✅ {command} command found"
else
    echo "❌ {command} command not found"
    exit 1
fi

# Test 2: Basic functionality
if {command} --version >/dev/null 2>&1; then
    echo "✅ {command} version check passed"
else
    echo "❌ {command} version check failed"
    exit 1
fi

echo "✅ All tests passed!"
```

## 📦 Pull Request Process

### Before Creating PR
1. **Update documentation** if you change functionality
2. **Add tests** for new features
3. **Update CHANGELOG.md** with your changes
4. **Ensure CI passes** (when available)

### PR Description Template
```
## Description
Brief description of changes and motivation.

## Type of Change
- [ ] Bug fix
- [ ] New feature  
- [ ] Documentation update
- [ ] Breaking change

## Testing
- [ ] Tested on Ubuntu 20.04+
- [ ] Tested on macOS (if applicable)
- [ ] All existing tests still pass
- [ ] Added new tests for changes

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review of code completed
- [ ] Documentation updated
- [ ] No new warnings introduced
```

### Review Process
1. **Automated checks** (linting, basic tests)
2. **Maintainer review** (code quality, design)
3. **Integration testing** (if significant changes)
4. **Merge** (squash and merge preferred)

## 🎯 Component Contribution Guidelines

### Adding New Components
1. **Create component directory** following naming conventions
2. **Use the documentation template** (`docs/TEMPLATE.md`)
3. **Include all required files** (README.md, install.sh, test.sh)
4. **Update main README** with component information
5. **Add to complete setup script** if appropriate

### Improving Existing Components
1. **Check existing issues** for known problems
2. **Test current functionality** before making changes
3. **Maintain backward compatibility** where possible
4. **Update documentation** to reflect changes

## 🔍 Development Environment

### Setting Up for Development
```bash
# Clone your fork
git clone https://github.com/your-username/system.git
cd system

# Create development branch
git checkout -b feature/your-feature-name

# Test current setup
./setup/complete_setup.sh --dry-run  # If available
```

### Useful Commands
```bash
# Run documentation checks
find . -name "*.md" -exec markdown-link-check {} \;

# Test specific component
cd component-name
./test.sh

# Validate shell scripts
shellcheck *.sh
```

## 🌟 Recognition

Contributors will be:
- Listed in the CONTRIBUTORS.md file
- Mentioned in release notes for significant contributions
- Given credit in component documentation they create/improve

## 📞 Getting Help

### For Contributors
- **Questions**: Use [GitHub Discussions](../../discussions)
- **Issues**: Check existing [issues](../../issues) first
- **Chat**: Join our community channels (when available)

### For Maintainers
- Review the [maintainer guide](maintainer-guide.md) (when available)
- Follow the [release process](release-process.md) (when available)

## 📜 Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code:

- **Be respectful** and inclusive
- **Be collaborative** and constructive
- **Be patient** with newcomers
- **Be professional** in all interactions

## 🙏 Thank You

Your contributions help make ML development environments more accessible to everyone. Every contribution, no matter how small, makes a difference!

---

**Questions?** Feel free to ask in [GitHub Discussions](../../discussions) or create an issue. 