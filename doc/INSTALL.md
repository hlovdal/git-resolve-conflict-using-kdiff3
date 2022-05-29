# Installation

## Linux/FreeBSD/unix

Copy `git-resolve-conflict-using-kdiff3` and `git-resolve-conflict-using-kdiff3.pl`
into a directory that is included in your `PATH` environment variable.

E.g.

```bash
cp git-resolve-conflict-using-kdiff3* $HOME/bin/.
```

The script has one perl library dependency, [`String::ShellQuote`](https://metacpan.org/pod/String::ShellQuote).
On Fedora/Centos/RedHat systems this can be installed with the package
`perl-String-ShellQuote` (and in this case you can probably just use the `*.pl`
file directly).

Alternatively you can use the embedded version in this repository by copying
the `dependencies/String` directory to the same directory that the script is
copied to.

E.g.

```bash
cp -r dependencies/String $HOME/bin/.
```

## Windows

Copy `git-resolve-conflict-using-kdiff3` and `git-resolve-conflict-using-kdiff3.pl`
into a directory that is included in your `PATH` environment variable.

E.g.

```bash
cp git-resolve-conflict-using-kdiff3* $HOME/bin/.
```

This script works both with [cygwin](https://www.cygwin.com/) and the `Git Bash`
window from [git for windows](https://www.git-scm.com/download/win).

The script has one perl library dependency, [`String::ShellQuote`](https://metacpan.org/pod/String::ShellQuote)
which is not available directly. So copy the `dependencies/String` directory
to the same directory that the script is copied to.

E.g.

```bash
cp -r dependencies/String $HOME/bin/.
```

Also copy the `kdiff3` script to launch KDiff3 (modify it if not installed as
`C:\Program Files\KDiff3\kdiff3.exe`).

E.g.

```bash
cp helpers/kdiff3 $HOME/bin/.
```

## Troubleshooting

Make sure that the scripts have the execute bit set (e.g.
`chmod +x $HOME/bin/git-resolve-conflict-using-kdiff3`).
