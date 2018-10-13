# This file is not supposed to be made directly
# It should instead be included (perhaps in a nested fashion from the top level makefile)
# Read the comments in the top level makefile for details


# This gives us the current directory relative to the root makefile
# patsubst removes the annoying slash we get on the end otherwise
# We need a unique name otherwise we'll overwrite the value of the calling Makefile
CUR_DIR_SYNTH := $(patsubst %/, %, $(dir $(lastword $(MAKEFILE_LIST))))

include $(CUR_DIR_SYNTH)/axis/Makefile
include $(CUR_DIR_SYNTH)/other/Makefile
