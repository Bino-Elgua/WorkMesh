# WorkMesh Development Workflow

This document outlines the development workflow, branch strategy, and contribution guidelines for the WorkMesh project.

## Branch Strategy

### Main Branches

#### `main`
- **Purpose**: Production-ready code
- **Protection**: Protected branch with required reviews
- **Deployment**: Automatically deployed to mainnet (when ready)
- **Merge Requirements**: 
  - All tests must pass
  - At least 2 code reviews required
  - Security review required for contract changes
  - No direct pushes allowed

#### `develop`
- **Purpose**: Integration branch for development features
- **Protection**: Semi-protected with required reviews
- **Deployment**: Automatically deployed to testnet
- **Merge Requirements**:
  - All tests must pass
  - At least 1 code review required
  - CI/CD pipeline must complete successfully

### Feature Branches

All development work should be done in feature branches following this naming convention:

#### Recommended Feature Branches

1. **`feature/marketplace-core`**
   - Implement core marketplace functionality
   - Complete job posting, bidding, and escrow creation
   - Add comprehensive error handling

2. **`feature/integration-tests`**
   - Complete integration test implementation
   - Add assert_abort_code checks
   - Implement multi-actor test scenarios

3. **`feature/agent-protocol`**
   - Develop A2A protocol integration
   - Add automated agent interfaces
   - Implement discovery and negotiation frameworks

4. **`feature/security-hardening`**
   - Address security audit findings
   - Implement additional security controls
   - Add comprehensive input validation

5. **`feature/ui-implementation`**
   - Build production-ready user interfaces
   - Implement wallet integration
   - Add real-time updates and notifications

6. **`feature/performance-optimization`**
   - Optimize gas usage
   - Improve registry lookup performance
   - Add caching mechanisms

### Branch Naming Conventions

```
feature/{feature-name}     # New features
bugfix/{bug-description}   # Bug fixes
hotfix/{critical-fix}      # Critical production fixes
refactor/{area-name}       # Code refactoring
docs/{documentation-area}  # Documentation updates
test/{test-area}          # Test improvements
```

## Development Workflow

### 1. Feature Development Process

```bash
# 1. Create and switch to feature branch from develop
git checkout develop
git pull origin develop
git checkout -b feature/marketplace-core

# 2. Implement feature with regular commits
git add .
git commit -m "Add job posting entry function"
git commit -m "Implement bid submission with validation"
git commit -m "Add escrow creation with milestone support"

# 3. Keep feature branch updated with develop
git fetch origin
git rebase origin/develop

# 4. Push feature branch
git push origin feature/marketplace-core

# 5. Create Pull Request to develop branch
# Use GitHub UI or CLI: gh pr create --base develop
```

### 2. Pull Request Requirements

#### For Feature Branches → `develop`

**Required Checks:**
- [ ] All tests pass (`sui move test`)
- [ ] Code compiles without warnings (`sui move build`)
- [ ] Linting passes (if configured)
- [ ] Integration tests complete successfully
- [ ] Documentation updated for new features

**Required Reviews:**
- [ ] At least 1 code review from team member
- [ ] Security review for contract changes (use SECURITY_REVIEW template)

**PR Template:**
```markdown
## Feature Description
Brief description of the feature and its purpose.

## Changes Made
- List of specific changes
- New functions added
- Modified structs or interfaces
- Test coverage additions

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed
- [ ] Gas usage analysis performed

## Security Considerations
- [ ] Authorization checks reviewed
- [ ] Input validation implemented
- [ ] State transition validation added
- [ ] Economic attack vectors considered

## Breaking Changes
List any breaking changes and migration requirements.

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests pass locally
```

#### For `develop` → `main`

**Required Checks:**
- [ ] All automated tests pass
- [ ] Security audit completed (for major releases)
- [ ] Performance benchmarks meet requirements
- [ ] End-to-end testing on testnet successful
- [ ] Deployment scripts tested and validated

**Required Reviews:**
- [ ] At least 2 code reviews from senior team members
- [ ] Security team approval for contract changes
- [ ] Product owner approval for feature completeness

### 3. Code Review Guidelines

#### For Reviewers

**General Review Points:**
- [ ] Code clarity and readability
- [ ] Proper error handling
- [ ] Test coverage adequacy
- [ ] Documentation completeness
- [ ] Performance considerations

**Sui Move Specific Review Points:**
- [ ] Proper use of shared objects
- [ ] Correct UID handling
- [ ] Authorization checks in place
- [ ] Balance management security
- [ ] Event emissions for state changes
- [ ] Gas efficiency considerations

**Security Review Points:**
- [ ] All "REVIEW SECURITY LOGIC" comments addressed
- [ ] Access control mechanisms properly implemented
- [ ] Input validation comprehensive
- [ ] State consistency maintained
- [ ] Economic attack vectors mitigated

#### Review Comments Format

Use conventional comment prefixes:
- `nit:` - Minor style/formatting suggestions
- `question:` - Clarification needed
- `suggestion:` - Alternative approach recommendation
- `issue:` - Potential problem that should be addressed
- `security:` - Security-related concern
- `performance:` - Performance optimization opportunity

### 4. Testing Requirements

#### Unit Tests
```bash
# Run unit tests
cd sui-workmesh
sui move test

# Run specific test module
sui move test --filter unit_tests

# Run with coverage (when available)
sui move test --coverage
```

#### Integration Tests
```bash
# Run integration tests
sui move test --filter integration_tests

# Run specific integration test
sui move test --filter test_concurrent_escrow_creation
```

#### End-to-End Testing
```bash
# Deploy to testnet
./scripts/deploy.sh testnet

# Run demo flow
./scripts/demo_flow.sh testnet basic

# Test advanced scenarios
./scripts/demo_flow.sh testnet advanced
```

### 5. Continuous Integration

#### GitHub Actions Workflow

```yaml
# .github/workflows/ci.yml
name: WorkMesh CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Sui
        run: |
          curl -fLJO https://github.com/MystenLabs/sui/releases/download/sui-v1.0.0/sui-ubuntu-x86_64.tgz
          tar -xzf sui-ubuntu-x86_64.tgz
          sudo mv sui /usr/local/bin/
          
      - name: Build contracts
        run: |
          cd sui-workmesh
          sui move build
          
      - name: Run tests
        run: |
          cd sui-workmesh
          sui move test
          
      - name: Security check
        run: |
          cd sui-workmesh
          # Run security analysis tools
          grep -r "REVIEW SECURITY LOGIC" contracts/sources/ || exit 0

  deploy-testnet:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to testnet
        run: |
          # Automated testnet deployment
          ./scripts/deploy.sh testnet
```

### 6. Release Process

#### Version Numbering
Follow semantic versioning (semver):
- `MAJOR.MINOR.PATCH`
- `MAJOR`: Breaking changes
- `MINOR`: New features (backward compatible)
- `PATCH`: Bug fixes (backward compatible)

#### Release Workflow
```bash
# 1. Create release branch
git checkout develop
git pull origin develop
git checkout -b release/v1.1.0

# 2. Update version numbers and changelog
# Update Move.toml version
# Update package.json versions
# Update CHANGELOG.md

# 3. Final testing and bug fixes
./scripts/deploy.sh testnet
./scripts/demo_flow.sh testnet advanced

# 4. Merge to main
git checkout main
git merge release/v1.1.0
git tag v1.1.0
git push origin main --tags

# 5. Deploy to mainnet (manual approval required)
./scripts/deploy.sh mainnet

# 6. Merge back to develop
git checkout develop
git merge main
git push origin develop
```

### 7. Security Guidelines

#### Pre-Commit Security Checks
```bash
# Security checklist before committing
./scripts/security-check.sh

# Manual security review points:
# 1. All authorization checks in place
# 2. Input validation comprehensive
# 3. Balance operations secure
# 4. State transitions valid
# 5. Economic attacks mitigated
```

#### Security Review Process
1. **Automated Security Scanning**: Run automated tools on every PR
2. **Manual Security Review**: Required for all contract changes
3. **External Security Audit**: Required before mainnet deployment
4. **Bug Bounty Program**: Ongoing community security testing

### 8. Documentation Requirements

#### Code Documentation
- All public functions must have comprehensive documentation
- Security-critical code must include "REVIEW SECURITY LOGIC" comments
- Complex algorithms require explanation comments
- Examples should be provided for API functions

#### Architecture Documentation
- Update ARCHITECTURE.md for major changes
- Document new object lifecycles
- Explain security model changes
- Include performance implications

#### API Documentation
- Update API.md for new functions
- Include usage examples
- Document error conditions
- Specify authorization requirements

### 9. Deployment Guidelines

#### Testnet Deployment
- Automated deployment on develop branch merges
- Used for integration testing and demos
- No special approval required

#### Mainnet Deployment
- Manual deployment with multiple approvals
- Security audit required
- Performance testing completed
- Rollback plan documented

#### Deployment Checklist
- [ ] All tests pass
- [ ] Security audit completed
- [ ] Performance benchmarks met
- [ ] Documentation updated
- [ ] Monitoring configured
- [ ] Rollback plan ready
- [ ] Team notification sent

### 10. Issue Tracking

#### Issue Labels
- `bug`: Something isn't working
- `feature`: New feature request
- `security`: Security-related issue
- `performance`: Performance optimization
- `documentation`: Documentation update needed
- `good-first-issue`: Suitable for new contributors

#### Issue Templates
Use GitHub issue templates for:
- Bug reports
- Feature requests
- Security vulnerabilities
- Performance issues

---

*This workflow is designed to ensure code quality, security, and maintainability while enabling efficient development. All team members should follow these guidelines to maintain project standards.*