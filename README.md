# auto-sync-deps

Automatically keep your yarn dependencies in sync with upstream
changes.

## Install

1. `yarn add --dev auto-sync-deps`
2. Edit `package.json` and add the following to the top level:

```js
  "husky": {
    "hooks": {
      "post-checkout": "yarn sync-deps",
      "post-merge": "yarn sync-deps"
    }
  }
```

## What it does

When first installed it will install/update any other
package trees you have in your project. That is, run `yarn` where
there are any `yarn.lock` files in git (excluding the one you're
installing this package to). This means when someone first
clones the project they just need to run `yarn` once, even if you
have multiple `package.json` package trees.

When change to a package tree (as in a change to a `yarn.lock`)
is pulled, merged, or checked out then that package tree is
updated. No more wondering why things aren't working because someone
has committed a package change and you haven't run `yarn`.

## What this handles

- The `package.json` you install into can be anywhere in your git
    tree, it doesn't have to be in the root
- Multiple `package.json` package trees, but only install this package
    in one of them

## Possible improvements

- Make it work with npm's `package-lock.json` and know which it
    should use
- Automatically install the husky git hooks, although it would have
    to leave the ability for you to add your own hooks still
