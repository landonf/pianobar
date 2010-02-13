# DO NOT EDIT
# This makefile makes sure all linkable targets are
# up-to-date with anything they link to, avoiding a bug in XCode 1.5
all.Debug: \
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/src/Debug/pianobar

all.Release: \
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/src/Release/pianobar

all.MinSizeRel: \
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/src/MinSizeRel/pianobar

all.RelWithDebInfo: \
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/src/RelWithDebInfo/pianobar

# For each target create a dummy rule so the target does not have to exist
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libpiano/src/Debug/libpiano.a:
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libwardrobe/src/Debug/libwardrobe.a:
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libwaitress/src/Debug/libwaitress.a:
/usr/local/lib/libfaad.dylib:
/usr/local/lib/libao.dylib:
/usr/local/lib/libmad.dylib:
/usr/lib/libm.dylib:
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libezxml/src/Debug/libezxml.a:
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libpiano/src/MinSizeRel/libpiano.a:
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libwardrobe/src/MinSizeRel/libwardrobe.a:
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libwaitress/src/MinSizeRel/libwaitress.a:
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libezxml/src/MinSizeRel/libezxml.a:
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libpiano/src/RelWithDebInfo/libpiano.a:
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libwardrobe/src/RelWithDebInfo/libwardrobe.a:
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libwaitress/src/RelWithDebInfo/libwaitress.a:
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libezxml/src/RelWithDebInfo/libezxml.a:
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libpiano/src/Release/libpiano.a:
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libwardrobe/src/Release/libwardrobe.a:
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libwaitress/src/Release/libwaitress.a:
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libezxml/src/Release/libezxml.a:


# Rules to remove targets that are older than anything to which they
# link.  This forces Xcode to relink the targets from scratch.  It
# does not seem to check these dependencies itself.
/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/src/Debug/pianobar:\
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libpiano/src/Debug/libpiano.a\
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libwardrobe/src/Debug/libwardrobe.a\
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libwaitress/src/Debug/libwaitress.a\
	/usr/local/lib/libfaad.dylib\
	/usr/local/lib/libao.dylib\
	/usr/local/lib/libmad.dylib\
	/usr/lib/libm.dylib\
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libezxml/src/Debug/libezxml.a
	/bin/rm -f /Users/syco/Projects/PlayerPiano/contrib/pianobar/build/src/Debug/pianobar


/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/src/Release/pianobar:\
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libpiano/src/Release/libpiano.a\
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libwardrobe/src/Release/libwardrobe.a\
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libwaitress/src/Release/libwaitress.a\
	/usr/local/lib/libfaad.dylib\
	/usr/local/lib/libao.dylib\
	/usr/local/lib/libmad.dylib\
	/usr/lib/libm.dylib\
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libezxml/src/Release/libezxml.a
	/bin/rm -f /Users/syco/Projects/PlayerPiano/contrib/pianobar/build/src/Release/pianobar


/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/src/MinSizeRel/pianobar:\
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libpiano/src/MinSizeRel/libpiano.a\
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libwardrobe/src/MinSizeRel/libwardrobe.a\
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libwaitress/src/MinSizeRel/libwaitress.a\
	/usr/local/lib/libfaad.dylib\
	/usr/local/lib/libao.dylib\
	/usr/local/lib/libmad.dylib\
	/usr/lib/libm.dylib\
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libezxml/src/MinSizeRel/libezxml.a
	/bin/rm -f /Users/syco/Projects/PlayerPiano/contrib/pianobar/build/src/MinSizeRel/pianobar


/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/src/RelWithDebInfo/pianobar:\
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libpiano/src/RelWithDebInfo/libpiano.a\
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libwardrobe/src/RelWithDebInfo/libwardrobe.a\
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libwaitress/src/RelWithDebInfo/libwaitress.a\
	/usr/local/lib/libfaad.dylib\
	/usr/local/lib/libao.dylib\
	/usr/local/lib/libmad.dylib\
	/usr/lib/libm.dylib\
	/Users/syco/Projects/PlayerPiano/contrib/pianobar/build/libezxml/src/RelWithDebInfo/libezxml.a
	/bin/rm -f /Users/syco/Projects/PlayerPiano/contrib/pianobar/build/src/RelWithDebInfo/pianobar


