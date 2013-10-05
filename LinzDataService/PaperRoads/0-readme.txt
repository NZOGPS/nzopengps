Tilename.txt are lists of the Linzid's (rna_id's) in each region that are 100% paper roads to ensure we can filter these from LINZ data comparisons.
No requirements on the formatting as long as the Linzid is the first entry in each line (refer Wellington example).

TilenamePaperNumbers.txt are lists of the Linzid's (rna_id's) in each region that have 'paper houses'  to ensure we can filter these from LINZ data comparisons.
'Paper houses' are addresses in the Linz data that do not represent a 'real' address, and cannot sensibly be represented by numbering in our map.
i.e. they are closest to a section of paper road.
The Linzid is the first entry in each line, followed by a tab delimited set of number ranges [OEB],startnum,endnum. Where O=Odd,E=Even, and B=both.

Tilename-Wrongside.txt are lists of Addresses that are detected as being on the 'wrong side' of the road compared to the numbering, but should be ignored. These should rarely be used. One case would be where different 'flats' are on different sides of the road - i.e. 15a on one side, and 15b on the other.

 Tilename-LINZWrongside.txt are lists of Addresses that appear on the wrong side of the road in LINZ data. These should be sent to LINZ for evaluation, and hopefully correction.
  
All these Files are most easily maintained using the 'paper roader' program.