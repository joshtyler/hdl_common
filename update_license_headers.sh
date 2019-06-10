#!/bin/bash

write_hdl_license() {
cat << EOF > $1
// Copyright (C) 2019 Joshua Tyler
//
//  This Source Code Form is subject to the terms of the                                                    │                                                                                                          
//  Open Hardware Description License, v. 1.0. If a copy                                                    │                                                                                                          
//  of the OHDL was not distributed with this file, You                                                     │                                                                                                          
//  can obtain one at http://juliusbaxter.net/ohdl/ohdl.txt

EOF
}

for FILE in $(find . -type f \( -iname '*.sv' -o -iname '*.v' \) )
do
  if ! grep -q Copyright $FILE
  then
  	echo "Patching $FILE"
  	TEMPFILE=$(mktemp)
  	write_hdl_license  $TEMPFILE
    cat $FILE >> $TEMPFILE
    mv $TEMPFILE $FILE
  fi
#  break
done