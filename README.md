# Free e-books published by Municipal Library in Prague - import to ALEPH

## Acknowledgements
I am obliged to give my thanks to Vojtěch Vojtíšek from [Municipal Library in Prague](https://www.mlp.cz) - MLP, who gave me information about these e-books and how to access them.
Big thanks also to Mark Phillipd vphill, who wrote [pyoaiharvester](https://github.com/vphill/pyoaiharvester) used in this process.

## Introduction
[Municipal Library in Prague](https://www.mlp.cz) is a publisher of e-books available freely from their website. As to current date (Nov. 11 2018), they offer more than 1300 titles in various formats friendly to e-book readers (devices) like epub, pdf, prc and others. 
Most of these titles are of fanatsy genre, including classic Czech and world writers in new (e-)edition, as well as works by current, rather less known authors. In the collection, one can find fairy-tailes, comics, horrors, fantasy, travellogues as well as factual books.

This collection is described in Municipal Library in Prague catalogue and can be downloaded using OAI-PMH protocol from URL:
`http://web2.mlp.cz/cgi/oai?verb=ListRecords&set=ebook&metadataPrefix=marc21`
However, this set "ebook" contain all e-books in the catalogue. The result must be than filter to record with publisher "Municipal Library in Prague" ("Mestska knihovna v Praze") or alike to get this collection of free e-books.

## Harvest and import to ALEPH
Main script for harvesting, processing and import is *eknihy_mlp_harvest.csh*, which uses the script *pyoaiharvester* for OAI-PMH harvesting, and `marcxml_ind_sort.xslt` for conversion from MarcXML to Aleph Sequential Format. Download and save these files somewhere on server to your directory with custom scripts, might in special subdirectory. After first run, two new subdirectories will be created there: ./log with log files and ./data with harvested data.

Edit the script `eknihy_mlp_harvest.csh` and modify general parameters in lines 26-36 according to your system state:
  
    #uvodni parametry
    set bib_base="XXX01" #ALEPH target BIB base, uppercase
    set oai_url='http://web2.mlp.cz/cgi/oai' #OAI address, no change needed
    set oai_set="ebook" #set for harvesting, no change needed
    set oai_format="marc21" #metadata format, resp. metadataPrefix for OAI harvesting, no change needed
    set script_home_dir="/exlibris/aleph/matyas/eknihy_mlp" #directory, where this script is stored and where also a file eknihy_mlp_harvest.last_harvest with last harvest timestamp is looked for when actualising collection
    set saxon_path='/exlibris/product/saxon/saxon9he.jar' #path and filename to Saxon. Minimal version is Saxon 9 HE (for lower version, you need to change arguments when calling saxon in this script.
    set bas_field_value='MKPfree' #value that is inserted to records to BAS fields. Can be used for filtering these record or creating logical base from them
    set admin_email='aleph.administrator@library.com' #if set, import results and errors are set to this address
    set cataloger_email='cataloguer@library.com' #if set, short results (not log) and new records are send to this address
    #konec parametru k nastaveni


You need to set new matching in your BIB base for Municipal Lib. Prague ID (stored in field MLP), CNB No. (Czech National Bibliography Number, field 15) and ISBN (field 20). To you BIB base *$data_tab/tab_match* add following lines:
     
     MLPID match_doc_gen                  TYPE=IND,TAG=MLP,CODE=MLP
     CNB   match_doc_gen                  TYPE=IND,TAG=015,SUBFIELD=a,CODE=CNB
     ISBN  match_doc_gen                  TYPE=IND,TAG=020##,CODE=SBN,SUBFIELD=a

To use this, you must have set direct indexes or access headings mentioned in column 3: MLPID, CNB, ISBN. This can be done adding lines to *$data_tab/tab11_ind* :
     
     MLP##                    MLP
     015                      CNB
     !for ISBN if you use expand_doc_bib_isxn expansion
     ISB                      SBN
     !for ISBN otherwise
     ISB                      020   a

and *$data_tab/tab00.eng* (tab00.cze etc.)

    H MLP   IND     21 00       00       MK v Praze ID
    H CNB   IND     20 00       00       Číslo ČNB


The new field MLP can be set in *tab01.eng* (tab01.cze) :

     D MLP   01 00 0000         MLP   LE-kniha MK v Praze


***

The script `eknihy_mlp_harvest.csh` can be run in two or three modes:

1. Full harvest - run it with argument "full" : `./eknihy_mlp_harvest.csh full`

2. Update

    i. since last update, when timestamp of last update is stored and looked for in file `eknihy_mlp_update.timestamp`. Run the script with no argument: `./eknihy_mlp_harvest.csh full`

    ii. since any date - run the script with argument "akt" and date YYYY-MM-DD : `./eknihy_mlp_harvest.csh akt yyyy-mm-dd`

### Workflow of the script
1. OAI-PMH Harvest
   
   1.1. check of harvest result

2. Conversion from Marc21slim (XML) to Aleph Sequential Format.
   
   2.1. If using ALEPH up to version 23 RC3025, the conversion procedure file-02 requires field indicators as xml attributes in this order: Indicator 1, Indicator 2. XSLT transformation `marcxml_ind_sort.xslt` is run to sort xml datafield arguments in this order. This has been corrected by Exlibris in ALEPH version 23, rep_change 003025. This xslt transformation can be ommited and removed from this script than.

    2.2. Conversion to Aleph Sequiential Format using Aleph procedure p-file-02

3. Filtering records where publisher (field 260,264) is something like 'Mestska knihovna v Praze' by regular expression '26[04].. L .\+M.\+stsk.\+ knihovn.\+ Pra[hz]'

4. Modification of records
    
    4.1. ID Number od the Municipal Libary in Prague is stored in field MLP
    
    4.2. Fields 856 with link to domain search.mlp.cz are removed - they link to Municipal Libary in Prague catalogue, not full texts of e-books

5. Matching and import to ALEPH - For this, you must set `tab_match` in BIB base - see above.
    
    5.1. Processed records are compared to records in ALEPH BIB base - **match against Municipal Lib. Prague ID** stored in field 001. For this, you must set `tab_match` in BIB base - see above. For records with 1 match - field 856 with links to ebook texts are updated using manage-18 procedure.  Records with more than 1 match are noticed in log (this also in following matches), no match goes on ...
    5.2. Processed records are compared to records in ALEPH BIB base - **match CNB No.** (Number of Czech National Bibliography, field 015). Fields 856 in records with 1 match would be updated. Still, these ebook records have no "CNB No" as to current state (2018 Nov. 11). 
    5.3. Processed records are compared to records in ALEPH BIB base - **match against ISBN** (field 020).  For records with 1 match - field 856 with links to ebook texts are updated and field BAS is added.  No match goes on to 6.

6. Importing new records
   Records without any match are imported with full Marc records using manage-18 procedure. These are reporte by e-mail to administrator and cataloguer.


### Schedule of running
Use should use `$alephe_tab/job_list` for scheduled running of this import - script eknihy_mlp_harvest.csh
In [Moravian-Silesian Reasearch Libary in Ostrava](https://www.svkos.cz) production enviroment, we run it once o month, which is not possible to determine in ALEPH job_list. As a solution, we have added extra script `eknihy_mlp_harvest4joblist.sh` scheduled for every day in job_list. By changing its 2nd line

     den_spousteni="08"
to desired day of month, the import script will run on this day-of-month.
Modify also following line with path to the import script eknihy_mlp_harvest.csh

     cesta_k_skriptum='/exlibris/aleph/matyas/eknihy_mlp'
 

### Dependencies, requirements
ALEPH version 20-23, Saxon - min. version 9 HE, OAI harvester in Python (included here)

### Author, License
Matyas Franciszek Bajger, [Moravian-Silesian Reasearch Libary in Ostrava](https://www.svkos.cz), 2018-11-07, ©2018
GNU Public License 3.0
