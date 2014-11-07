$^I = "~";
while (<>){
	print unless /Codepage/ or /LblCoding/;
}