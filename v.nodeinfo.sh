#!/bin/sh
############################################################################
#
# MODULE:	v.nodeinfo
#
# AUTHOR(S):	Huidae Cho <grass4u gmail.com>
#
# PURPOSE:	Finds node information
#
# COPYRIGHT:	(C) 2021 by Huidae Cho
#
#		This program is free software under the GNU General Public
#		License (>=v2). Read the file COPYING that comes with GRASS
#		for details.
#
############################################################################

#%module
#% description: Finds node information; populates and creates sx, sy, ex, ey, snode, and enode columns first, if they do not already exist
#%end

#%option G_OPT_V_MAP
#%end

#%option G_OPT_V_FIELD
#%end

#%option
#% key: nodes
#% type: integer
#% description: Node IDs
# multiple: yes
#%end

if [ -z "$GISBASE" ]; then
	echo "ERROR: You must be in GRASS GIS to run this program." >&2
	exit 1
fi

if [ "$1" != "@ARGS_PARSED@" ]; then
	exec g.parser "$0" "$@"
fi

map="$GIS_OPT_MAP"
layer="$GIS_OPT_LAYER"
nodes=$(echo $GIS_OPT_NODES | sed 's/,/ /g')

## just once to populate snode and enode columns

populate=0

if ! v.db.connect -c map=$map layer=$layer | grep '|snode$' > /dev/null; then
	populate=1
fi
if ! v.db.connect -c map=$map layer=$layer | grep '|enode$' > /dev/null; then
	populate=1
fi

if [ $populate -eq 1 ]; then
	echo "Populating node information..." >&2

	echo "Adding columns to map=$map layer=$layer: sx, sy, ex, ey, snode, enode" >&2
	v.to.db map=$map layer=$layer op=start col=sx,sy --o
	v.to.db map=$map layer=$layer op=end col=ex,ey --o
	v.db.addcolumn map=$map layer=$layer col="snode int, enode int"

	for i in $(v.db.select -c map=$map layer=$layer col=cat,sx,sy sep=,); do
		cat=$(echo $i | cut -d, -f1)
		coor=$(echo $i | cut -d, -f2-3)
		snode=$(v.what -dg map=$map layer=$layer type=line coor=$coor | sed '/^Node\[0\]=/!d; s/^.*=//')
		v.db.update map=$map layer=$layer col=snode value=$snode where=cat=$cat
	done

	for i in $(v.db.select -c map=$map layer=$layer col=cat,ex,ey sep=,); do
		cat=$(echo $i | cut -d, -f1)
		coor=$(echo $i | cut -d, -f2-3)
		enode=$(v.what -dg map=$map layer=$layer type=line coor=$coor | sed '/^Node\[1\]=/!d; s/^.*=//')
		v.db.update map=$map layer=$layer col=enode value=$enode where=cat=$cat
	done
fi

## end of just once

echo "node_id,cat,feature_id,node_type"

for node_id in $nodes; do
	for node_type in start end; do
		if [ "$node_type" = "start" ]; then
			senode=snode
		else
			senode=enode
		fi
		for cat in $(v.db.select -c map=$map layer=$layer col=cat where="$senode=$node_id"); do
			for feature_id in $(v.edit map=$map layer=$layer tool=select cat=$cat 2> /dev/null | sed 's/,/ /g'); do
				echo "$node_id,$cat,$feature_id,$node_type"
			done
		done
	done
done
