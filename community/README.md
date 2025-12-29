# Community Patches & Icons

This directory contains community-maintained patches and icons for Emacs+.

**[→ Browse Icons Gallery](./icons/README.md)** - View all 76 available icons with previews.

## Important

**You are responsible for maintaining features you use from this directory.**

- The formula maintainer provides infrastructure only (no SLA)
- Community members maintain individual patches/icons
- Features may break with Emacs updates
- Maintainers may disappear or abandon patches

## Three-Tier System

### Built-in Patches
- Maintained by formula maintainer
- Applied unconditionally
- Must fix ASAP if broken

### Community Patches & Icons
- Maintained by community (you!)
- Opt-in via `build.yml`
- No SLA - can break

### Wild-West
- Any external URL
- Requires SHA256 hash
- Maximum flexibility

## Using Community Features

Create `~/.config/emacs-plus/build.yml`:

```yaml
patches:
  - patch-name-from-registry
  - my-patch:
      url: https://example.com/external.patch
      sha256: abc123...

icon: icon-name-from-registry
# OR
icon:
  url: https://example.com/external.icns
  sha256: def456...
```

See `registry.json` for available features.

## Contributing

### Submitting a Patch

1. Run the helper script:
   ```bash
   ./scripts/create-community-patch.rb
   ```

2. The script will:
   - Create proper directory structure
   - Generate metadata
   - Test patch application with each Emacs version
   - Guide you through next steps

3. Add entry to `registry.json`

4. Submit PR

### Submitting an Icon

1. Run the helper script:
   ```bash
   ./scripts/create-community-icon.rb
   ```

2. Add entry to `registry.json`

3. Submit PR

### Patch Requirements

- Must include `metadata.json` with:
  - Name, description
  - Maintainer GitHub username
  - Compatible Emacs versions
- Must include version-specific patch files: `emacs-29.patch`, `emacs-30.patch`, etc.
- Must include README.md explaining what it does
- Must apply cleanly on specified Emacs versions
- Should include upstream URL if applicable

### Icon Requirements

- Must be valid `.icns` file
- Must include `metadata.json`
- Should include preview image
- Must include maintainer contact

## Review Process

The formula maintainer will:
- Verify metadata format
- Check for malicious code
- Ensure proper directory structure
- Test that patch/icon works initially
- **NOT** maintain your patch/icon long-term
- **NOT** fix breakages from Emacs updates

## Maintenance

As a maintainer of a community feature:

- Respond to issues about your feature (or delegate to others)
- Update when Emacs versions change
- Mark as deprecated if no longer working
- Transfer maintainership if stepping away

## Abandoned Features

Features may be removed from the registry if:
- Maintainer is unresponsive for 3+ months
- Patch no longer applies to any supported Emacs version
- Security concerns are raised and not addressed

## Support

Issues with community features should be directed to the maintainer listed in metadata.json, not to the formula maintainer.

Formula maintainer will only help with:
- Registry/infrastructure issues
- Helper script problems
- Config file format questions
