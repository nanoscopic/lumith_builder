# lumith_builder
Modularized build system featuring XML tagged preprocessing / metaprogramming

This project is a build system for building Perl/JS systems from collections of modules.
Each set of interdependent modules, when build, is called a 'system'. Systems can be interdependent,
loading modules from other systems. Modules names can be reused in different systems, because modules
are imported to a specific name when used.

The build system itself cannot be run until it is, itself, built. The prebuilt directory is a
prebuilt version of the builder so that this can be done. It was created through a series of bootstrapping
exercises. That process was not itself clean; the bootstrapping required manual alterations after build
to make it work properly to build itself. At this point it is now possible to build a new clean built
builder, and then rebuild the builder once more without any issues.

The build system does many things. The most interesting and notable thing it does is let you interpose
XML metaprogramming tags into the middle of Perl or JS code. Such XML tags are then expanded into actual
code similar to the way other preprocessor macros are used in various other languages. The way it is done
in this build is meant to be language agnostic. There is a small amount of glue that must be created
in each language for the builder to work properly with a new language. Currently onto Perl and JS are
fully functional and tested.

The XML tags used to generate code can additionally generate more XML tags. Those will in turn be processed.
In this way the XML tags are a form of metaprogramming and much more flexible than standard one pass
preprocessing systems.

The builder also provides a mechanism for templates intermixed into code to be converted into code to
output the template. This is done to prevent the need to compile templates during runtime, and furthermore
to make it possible to compile templates using a different langauge than the language which the template
is actual run from.

The builder provides a mechanism for having custom XML configuration per module and system. The configuration
can override itself in layers. The way this works needs more explanation, but suffice it to say it is there
and should be used to configure things.

Various stuff in this project is hardcoded to a path of /home/user/lumith_builder. If those paths are not
changed one would need to clone the repo to that path on your local system to be able to rebuild things.

Only the source files are tagged with a Copyright notice. Despite that the entire contents of this repo shall
be noted to be Copyright (C) 2018 David Helkowski. The Copyright is simply left out of the XML files and
prebuilt files as it does not, in my opinion, belong in those places.

Some amount of code is copied into build projects. No exception is made to allow the license of such built
code to different from AGPL.
