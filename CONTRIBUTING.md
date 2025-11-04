# Contribution Guidelines for NekoDevOS 🐱

Thank you for your interest in contributing to NekoDevOS! This project is made with ❤️ by the community for the community.

## 🌸 How to Contribute

### Reporting Bugs 🐛
1. Check if the issue already exists
2. Use the bug report template
3. Include:
   - OS version
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots if applicable

### Suggesting Features ✨
1. Open an issue with the feature request template
2. Describe the feature clearly
3. Explain why it would be useful
4. Include mockups if applicable

### Adding Themes 🎨
1. Create your theme following the existing format
2. Place it in the appropriate directory:
   - KDE themes: `customization/themes/`
   - Wallpapers: `customization/wallpapers/`
   - Plymouth themes: `customization/plymouth/`
3. Update documentation
4. Submit a pull request

### Improving Documentation 📚
- Fix typos, improve clarity
- Add examples
- Translate to other languages
- Update outdated information

## 🚀 Development Process

### Setting Up Development Environment
```bash
# Fork and clone the repository
git clone https://github.com/YOUR_USERNAME/NekoDevOS.git
cd NekoDevOS

# Create a new branch
git checkout -b feature/your-feature-name
```

### Making Changes
1. Make your changes
2. Test thoroughly
3. Follow the code style
4. Update documentation
5. Commit with clear messages

### Commit Message Format
```
type(scope): brief description

Detailed explanation if needed

Fixes #issue_number
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting, styling
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance

### Submitting Pull Requests
1. Push to your fork
2. Create a pull request to `dev` branch
3. Fill out the PR template
4. Wait for review
5. Address feedback

## 📝 Code Style Guidelines

### Bash Scripts
- Use `#!/bin/bash` shebang
- Include comments for complex logic
- Use meaningful variable names
- Add error handling with `set -e`
- Use functions for reusability

Example:
```bash
#!/bin/bash
set -e

# Description of what this function does
my_function() {
    local param=$1
    echo "Processing: $param"
}
```

### Configuration Files
- Use clear, descriptive comments
- Maintain consistent formatting
- Follow existing patterns
- Document non-obvious settings

## 🎨 Theme Guidelines

### Wallpapers
- Resolution: 1920x1080 or higher
- Format: PNG or JPG
- Size: Under 5MB per image
- Ensure proper licensing/permissions
- Anime-themed, SFW content only

### Color Schemes
- Provide light and dark variants
- Ensure good contrast (WCAG AA)
- Test with colorblind simulators
- Include preview screenshots

## 🧪 Testing

### Before Submitting
- [ ] Test on clean Ubuntu installation
- [ ] Verify all scripts execute without errors
- [ ] Check that documentation is accurate
- [ ] Ensure changes don't break existing features
- [ ] Test on both KDE and XFCE (if applicable)

### Build Testing
```bash
# Test the build process
sudo ./build.sh

# Verify ISO creation
ls -lh output/
```

## 📋 Pull Request Checklist
- [ ] Branch is up to date with `dev`
- [ ] Code follows style guidelines
- [ ] Documentation is updated
- [ ] Commits are clean and descriptive
- [ ] Changes are tested
- [ ] No merge conflicts

## 🤝 Community Guidelines

### Be Respectful
- Treat everyone with respect
- Welcome newcomers
- Provide constructive feedback
- Be patient with questions

### Be Collaborative
- Share knowledge
- Help others
- Credit contributors
- Discuss major changes before implementing

### Be Professional
- Keep discussions on-topic
- Avoid spam and self-promotion
- Don't share NSFW content
- Respect copyright and licenses

## 📜 Licensing

By contributing, you agree that your contributions will be licensed under the MIT License.

### Content Guidelines
- Only contribute content you have rights to use
- Respect original artists and creators
- Include proper attribution
- Follow fair use guidelines

## ❓ Questions?

- Open an issue for questions
- Join discussions in existing issues
- Check the wiki for answers
- Be specific about your question

## 🎯 Priority Areas

We especially welcome contributions in:
- [ ] Additional anime themes
- [ ] Performance optimizations
- [ ] Documentation improvements
- [ ] Bug fixes
- [ ] Accessibility features
- [ ] Localization (translations)
- [ ] Testing and quality assurance

## 🌟 Recognition

Contributors will be:
- Added to `CONTRIBUTORS.md`
- Mentioned in release notes
- Forever appreciated! 💖

---

Thank you for contributing to NekoDevOS! Together we make it better! (◕‿◕)✨
