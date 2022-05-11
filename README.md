
# What is this?

This is a script that will launch [KDiff3](http://kdiff3.sourceforge.net/) with
a 3-way merge view to resolve the conflicts.

## Benefits

By default git will just add text conflict markers in the file with conflict,
but that is only giving context from **two** versions, having a full **3-way**
context is vastly superior (as well as being graphical is much easier to easier
to review).

And by using KDiff3 you will able to both review (and override) all the
automatically resolved conflicts. Being able to see which versions that were
selected automatically can often be a big help in determing how to resolve
conflicts that were not automatically resolved.

# Usage

## Example repository with a conflict

This is an example where the file `.gitignore` is modified on two branches,
which results in a conflict when rebasing. The changes are basically the same
but one of them also adds a comment.

```bash
$ git init
Initialized empty Git repository in C:/Temp/test/.git/
$ touch .gitignore
$ git add .gitignore
$ git ci -m .gitignore
[main (root-commit) 7a3154e] .gitignore
 1 file changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 .gitignore
$ echo '*.bak' >> .gitignore
$ git add .gitignore
$ git ci -m "Ignore *.bak"
[main 61ce3cc] Ignore *.bak
 1 file changed, 1 insertion(+)
$ git checkout -b testbranch HEAD^
Switched to a new branch 'testbranch'
$ (echo '#Ignore backup files'; echo '*.bak' ) >> .gitignore
$ git add .gitignore
$ git ci -m "Ignore backup files"
[testbranch 877d160] Ignore backup files
 1 file changed, 2 insertions(+)
$ git rebase main testbranch
Auto-merging .gitignore
CONFLICT (content): Merge conflict in .gitignore
error: could not apply 877d160... Ignore backup files
hint: Resolve all conflicts manually, mark them as resolved with
hint: "git add/rm <conflicted_files>", then run "git rebase --continue".
hint: You can instead skip this commit: run "git rebase --skip".
hint: To abort and get back to the state before "git rebase", run "git rebase --abort".
Could not apply 877d160... Ignore backup files
$ gitk --all &
[1] 26349
$
```

![Gitk screenshot](doc/images/gitk_conflict.png)

## Resolving the conflict

Running the script will present a list of the files that has conflict and ask
to launch kdiff3:

![Running script screenhot](doc/images/run_script_001.png)

Answering yes launches KDiff3:

![KDiff3 screenshot, initial](doc/images/kdiff3_initial.png)

and by using KDiff3's *manual diff allignment* on the `*.bak` lines we can get
KDiff3 to resolve this automatically:

![KDiff3 screenshot, manual diff alignmet](doc/images/kdiff3_manual_diffalignment.png)

Saving and quiting KDiff3, the script asks if you are satisfied with the result
and want to add the file to the index:

![Running script screenshot](doc/images/run_script_002.png)

With all conflicts resolved, you can run `git rebase --continue`.

# Installation

This script has the following external dependencies:

* perl (which you will already have when using git)
* KDiff3

If you want to run the script directly from a clone of this repository,
you can do so:

```shell
cd /some/where
git clone https://github.com/hlovdal/git-resolve-conflict-using-kdiff3
cd git-resolve-conflict-using-kdiff3
git checkout runtime-unix         # Choose one of these
git checkout runtime-windows      # Choose one of these
export PATH="$PATH:/some/where/git-resolve-conflict-using-kdiff3"
```

Otherwise follow instructions in [INSTALL.md](./INSTALL.md):

# Troubleshooting

Make sure that the scripts have the execute bit set (e.g.
`chmod +x $HOME/bin/git-resolve-conflict-using-kdiff3`).

# Background/history

Q: Have you not heard about mergetool?

A: Yes, but this is a general tool for any command that can result in
conflicts, not just `merge` e.g. also `revert`, `cherry-pick`, `rebase`
(and `stash apply/pop`).

I think mergetool perhaps handles some of these now as well, but I am quite
sure it did not when I started writing this script many, many years ago.
But even if there is a 100% overlap in support, I think this script has better
behaviour.
