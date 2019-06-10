#!/bin/bash

#  Copyright (C) 2019 Joshua Tyler
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#  See the file LICENSE_LGPL included with this distribution for more
#  information.


# Patch all files matching the extensions listed
# First arg is the license writing function
# Other args are file extension regexes (case insensitive)
patch_files() {
	FUNC=$1
	shift
	for FILE in $( echo "$*" | xargs -n1 find . -type f -iname  )
	do
	  if ! grep -q Copyright $FILE ; then
	  	echo "Patching $FILE"
	  	TEMPFILE=$(mktemp)
	  	$FUNC $TEMPFILE
	    cat $FILE >> $TEMPFILE
	    mv $TEMPFILE $FILE
	  else
	  	echo "Not patching $FILE"
	  fi
	done
}

# Write out the license to a file 
# Arg 1 is the file to write to
write_ohdl_1_0_header() {
cat << EOF > $1
// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │                                                                                                          
//  Open Hardware Description License, v. 1.0. If a copy                                                    │                                                                                                          
//  of the OHDL was not distributed with this file, You                                                     │                                                                                                          
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

EOF
}

write_lgpl_2_1_header_slashes() {
cat << EOF > $1
//  Copyright (C) 2019 Joshua Tyler
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//  See the file LICENSE_LGPL included with this distribution for more
//  information.

EOF
}

write_lgpl_2_1_header_hashes() {
cat << EOF > $1
#  Copyright (C) 2019 Joshua Tyler
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#  See the file LICENSE_LGPL included with this distribution for more
#  information.

EOF
}

# Write out header for HDL files
patch_files write_ohdl_1_0_header "*.sv" "*.v"

# Write out header for software files
patch_files write_lgpl_2_1_header_slashes "*.cpp" "*.hpp"

# Write out header for Makefiles
patch_files write_lgpl_2_1_header_hashes "*Makefile*"
