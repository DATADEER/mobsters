* the tilemap is procedurally generated but supports a seed so you can generate the same tilemap again
* each tilemap contains 4 hq's, one for each player. the hq's are always on opposing sites of the map, never grouped together
* the rest of the maps consists of store_generic and tile_empty
* each store_generic MUST HAVE at least 1 orthogonal neighbor.
* the hq MUST HAVE at leasto 2 orthogonal neighbor stores
* the hq is always surrounded by other tiles, it's never among the outermost tiles of the grid 
* ALL orthogonal neighbors of owned tiles (HQ and captured stores) should be highlighted with tile_adjacent.png overlay to show capturable territories