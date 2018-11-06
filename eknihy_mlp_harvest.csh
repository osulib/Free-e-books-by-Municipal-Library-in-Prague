#!/bin/csh -f
#
#skript pro OAI sklizen volne dostupnych e-knih Mestske knihovnz v Praze a jejich import do Alehu
#autor: Matyas Bajger, 2018
#
#Workflow: 
#    1. sklizen oai z adresy mlp, bud uplna nebo aktualizacni podle parametru spusteni
#    2. mapovani dle id knih mlp
#    3. nenamatchovane mapovani dle cnb, pak isbn, ty pak doplnit
#    4. zcela nenamatchovane nebo s vic nez 1 matchem importovat nebo upozornit mailem
#
#parametry spousteni
#  full  : provede se kopletni harvest
#  akt .....  : provede se harvest od timestampu, ten je pa zadadn jako druhy parametr misto tecek ve formatu pozadavoanem OAI
#                             pro oai mlp to muze byt format yyyy-mm-dd
#               aktualizace provadi se do vcerejsiho data nez je aktualni, tim na sebe nevazuje jejich pravidelne spousteni
#bez parametru - provede se aktualizacni harvest od posledniho timestampu ulozeneho v souboru eknihy_mlp_harvest.last_harvest
#
#Pouziva pyoaiharvester - harvester OAI v Pythonu by Mark Phillipd vphill - https://github.com/vphill/pyoaiharvester

#BUG1 - Aleph22 procedura file-01 konverze z MarcXML potrebuje u datafield elementu poradi atributu tag, ind1, ind2.
      # opraveno v Aleph ver. 23, rep_change 003025 
      # prozatimni reseni pomoci xslt a Saxon - min. verze 9!!

#uvodni parametry
set bib_base="MVK01" #kam se ma importovat, uppercase
set oai_url='http://web2.mlp.cz/cgi/oai' #zakladni adresa pro sklizen
set oai_set="ebook" #set co se ma sklizet
set oai_format="marc21" #metadatformat, resp. metadataPrefix pro sklizen
set script_home_dir="/exlibris/aleph/matyas/eknihy_mlp" #domovsky adresar, kde se ocekava soubor s poslednim casovym razitkem eknihy_mlp_harvest.last_harvest
           # harvestor pyoaiharvest.py a take tento skript
           # pod tuoto cestou se vtvori adresare ./data se stazenymi daty a ./log s logy importu
set saxon_path='/exlibris/product/saxon/saxon9he.jar' #cesta k a filename saxonu, minimalne verze 9, je vyzadovano pro BUG1
set bas_field_value='MKPfree' #tato hodnota se vlozi do novych zaznamu pole BAS, podpole a - pro definici logicke baze
set admin_email='bajger@svkos.cz' #pokud je zadana hodnota, poslou se na ni vysledky nebo chyby behu
set cataloger_email='smekalova@svkos.cz' #pokud je zadana hodnota, poslou se na ni strucne vysledky a nove zaznamy (nikoli chyby a/nebo log)
#konec parametru k nastaveni

set now=`date +'%Y%m%d-%H:%M'`
set today=`date +'%Y-%m-%d'`
set today2=`date +'%Y%m%d'`
set yesterday=`date +'%Y-%m-%d' --date="1 days ago"`
#kontrola parametru
if ( ! -d "$script_home_dir" ) then
  echo "ERROR - adresar $script_home_dir zadany jako uvodni parametr v tomto skriptu NENALEZEN. Nemohu pokracovat"
  if ( "$admin_mail" != '') then
     mail -s "eknihy_mlp_harvest.csh ERRROR - nenaleyen adresar script_home_dir - $script_home_dir" $admin_email
  endif
  exit 1;
endif
if ( ! -d "$script_home_dir/log" ) then
  mkdir "$script_home_dir/log"
endif
set log_file="$script_home_dir/log/eknihy_mlp.log$today"
set log_file4mail="$script_home_dir/log/eknihy_mlp.log.txt"
echo "START $now" | tee -a $log_file
cp /dev/null "$log_file4mail"
if ( ! -f "$script_home_dir/pyoaiharvest.py" ) then
  echo "ERROR - soubor pyoaiharvest.py pro sklizeni NENALEZEN v adresar $script_home_dir zadanem jako uvodni parametr v tomto skriptu NENALEZEN. Nemohu pokracovat" | tee -a $log_file
  goto error
endif
if ( $1 == "full" || $1 == "FULL" ) then
  echo "Starting FULL harvest - `date`" | tee -a $log_file 
  set data_file="$script_home_dir/data/eknihy_mlp_full_$today.xml"
  set data_file_filename="eknihy_mlp_full_$today"
else if ( $1 == "akt") then
  if ( $2 == "" ) then
    echo "ERROR - zadan parametr akt pro aktualizaci, ale chybi druhy parametr s datumem od kdy se ma aktualizovat" | tee -a $log_file
    goto error
  endif
  set date_from=$2
  echo "Starting actualisation harvest from $date_from - `date`" | tee -a $log_file 
  set data_file="$script_home_dir/data/eknihy_mlp_from$date_from""_to$yesterday.xml"
  set data_file_filename="eknihy_mlp_from$date_from""_to$yesterday.xml"
else 
  if ( ! -f "$script_home_dir/eknihy_mlp_harvest.last_harvest" ) then 
    echo "ERROR - soubor s datumem posledni aktualizace $script_home_dir/eknihy_mlp_harvest.last_harvest NENALEZEN. Nemohu pokracovat" | tee -a $log_file
    goto error
  endif
  set date_from=`cat "$script_home_dir/eknihy_mlp_harvest.last_harvest"`
  set data_file="$script_home_dir/data/eknihy_mlp_from$date_from""_to$yesterday.xml"
endif
  


#sklizen
echo "Going to harvest ..." | tee -a $log_file
if ( ! -d "$script_home_dir/data" ) then
   mkdir "$script_home_dir/data"
endif
if ( $1 == "full" || $1 == "FULL" ) then
   python "$script_home_dir/pyoaiharvest.py" -l "$oai_url" -s "$oai_set" -m "$oai_format" -o "$data_file" | tee -a $log_file
else
   if ( `echo $date_from | grep '[0-9]\{4\}\-[0-9]\{2\}\-[0-9]\{2\}' -c | bc` != 1 ) then
      echo "ERROR - datum $date_from zadane jako vstupni parametr aktualizace nebo nalezene v souboru $script_home_dir/eknihy_mlp_harvest.last_harvest nema pozadovany FORMAT yyyy-mm-dd. Nemohu pokracovat." | tee -a $log_file
      exit 0
   endif
   python "$script_home_dir/pyoaiharvest.py" -l "$oai_url" -s "$oai_set" -m "$oai_format" -f $date_from -u $yesterday -o "$data_file" | tee -a $log_file
endif

#check vysledku harvestu
if ( ! -f $data_file ) then
  echo "ERROR - soubor s vysledky sklizne $data_file NENALEZEN. Sklizen nejak neprobehla." | tee -a $log_file
  goto error
endif
if ( `xmlwf $data_file | wc -m | bc` != 0 ) then
  echo "ERROR - sklizeny soubor $data_file neni XML Well formed :" | tee -a $log_file
  xmlwf $data_file | tee -a $log_file
  goto error
endif
if ( `grep -ic '<error' $data_file | bc` != 0 ) then
  echo "ERROR - v sklizenem souboru $data_file je nejaka chyba :" | tee -a $log_file
  grep -i -n2 '<error' data_file | tee -a $log_file
  goto error
endif
if ( `grep -ic '<record' $data_file | bc` == 0 ) then
  echo "Sklizeny xml soubor $data_file neobsahuje zadne zaznamy (<record>), neni co importovat" | tee -a $log_file
  goto error
endif

#konverze marc21slim na Aleph seq format
printf "\nConverting Marc21slim to Aleph sequential format...\n\n" | tee -a $log_file
#BUG1
if ( ! -f $saxon_path ) then
  echo "ERROR - Saxon pro xslt transofrmaci v ramci BUG1 nenalezen - saxon_path : $saxon_path. Exit." | tee -a $log_file
  goto error
endif
java -jar "$saxon_path" -s:$data_file -o:$data_file.tmp -xsl:$script_home_dir/marcxml_ind_sort.xslt
if ( ! -f $data_file.tmp ) then
  echo "ERROR - nenalezen vysledek xslt transformace BUG1 : $data_file.tmp. Chyba pri xslt transformaci, zda se." | tee -a $log_file
  goto error
endif
mv -v $data_file.tmp $data_file
#BUG1 end
set bib_baseL=`echo $bib_base | aleph_tr -l`
cp $data_file "$alephe_dev/$bib_baseL/scratch/eknihy_mlp.xml"
csh -f $aleph_proc/p_file_02 "$bib_base,eknihy_mlp.xml,eknihy_mlp.seq,06," | tee -a $log_file
if ( ! -f "$alephe_dev/$bib_baseL/scratch/eknihy_mlp.seq" ) then
  echo "ERROR: Vysledek konverze marc21 slim do Aleph sequential format pomoci p_file_02 nenalezen - soubor $alephe_dev/$bib_baseL/scratch/eknihy_mlp.seq" | tee -a $log_file
  goto error
endif
cp "$alephe_dev/$bib_baseL/scratch/eknihy_mlp.seq" "$data_file.seq"

printf "\nSklizeno a do Aleph sekvencniho konvertovano `awk '{print $1;}' $data_file.seq | sort -u | grep $ -c` zaznamu.\n\n" | tee -a $log_file
#v sklizenem setu ebooks jsou vsechny eknihy v katalogu MLP
#dle email doluvz s Vojtech Vojtisek odpovidaji jejich volne pristupnym ekniham ty co maji nakladatele (pole 260,264) "Mestska knihovna v Praye
#odfitltrovani jen co je 260/264 Mestska knihovna v Praze
grep '^......... 26[04].. L .\+M.\+stsk.\+ knihovn.\+ Pra[hz]' "$data_file.seq" | awk '{print "^"$1;}' | sort -u >$script_home_dir/eknihy_mlp.tmp
grep -f $script_home_dir/eknihy_mlp.tmp "$data_file.seq" >"$data_file.seq.tmp"
mv -v "$data_file.seq.tmp" "$data_file.seq" 
rm -f $script_home_dir/eknihy_mlp.tmp
printf "\n Po vyberu jen e-knih Mestske knihovny v Praze pripraveno k importu `awk '{print $1;}' $data_file.seq | sort -u | grep $ -c` zaznamu.\n\n" | tee -a $log_file


#uprava importu 
#   1. pole 001 se zmeni na pole MLP - pole s idenfifik.c. Mestske knih. a prida se mu prefix mlp
sed -i -e 's/^\([[:digit:]]\{9\}\) 001   L /\1 MLP   L mlp/' "$data_file.seq"
#   2. odstraneni 856 s linkem na domenu search.mlp.cz - vede na OPAC MLP
grep -v '^......... 856.*search.mlp/cz' "$data_file.seq" >"$data_file.seq.tmp"
mv -v "$data_file.seq.tmp" "$data_file.seq"


#mapovani se stavajicimi zaznamy v alephu

#a] mapovani proti 001 - ident. cislo mlp
set ds="$alephe_dev/$bib_baseL/scratch"
cp "$data_file.seq" "$ds/$data_file_filename.seq"
csh -f $aleph_proc/p_manage_36 "$bib_base,$data_file_filename.seq,$data_file_filename.tmp.nomatch001,$data_file_filename.match001,$data_file_filename.err001,MLPID," | tee -a $log_file
# 1 match - aktualizace jen poli 856
if ( -f "$ds/$data_file_filename.match001") then
   if ( ! -z "$ds/$data_file_filename.match001") then
      printf "\nV katalogu nalezeno `awk '{print $1;}' $ds/$data_file_filename.match001 | sort -u | grep $ -c` zaznamu se shodnym ID MLP, aktualizuje se u nich pole 856.\n\n" | tee -a $log_file
      #pokud tam bude jine nez mlp tak by se smazalo, proto nejdriv print03, cele to poskladat a pak importovat
      awk '{print $1;}' "$ds/$data_file_filename.match001" | sort -u | sed 's/$/@@@/' | sed "s/@@@/$bib_base/" >$alephe_scratch/mlp001.sys
      csh -f $aleph_proc/p_print_03 "$bib_base,mlp001.sys,856##,,,,,,,,mlp001.856,A,,,,N,"
      grep -v 'mlp.cz' "$ds/mlp001.856" >>"$ds/$data_file_filename.match001"
      mv -v "$ds/$data_file_filename.match001" "$ds/$data_file_filename.match001.tmp"
      sort "$ds/$data_file_filename.match001.tmp" >"$ds/$data_file_filename.match001"
      sort "$ds/$data_file_filename.match001.tmp" >"$alephe_scratch/$data_file_filename.match001"
      rm -f "$ds/$data_file_filename.match001.tmp"
      #import
      # protahne fixem MLPEB, ale zde neni treba csh -f $aleph_proc/p_manage_18 "$bib_base,$data_file_filename.match001,$data_file_filename.match001.reject,$data_file_filename.match001.log,OLD,MLPEB,,FULL,COR,M,,,mlp,10," 
      csh -f $aleph_proc/p_manage_18 "$bib_base,$data_file_filename.match001,$data_file_filename.match001.reject,$data_file_filename.match001.log,OLD,MLPEB,,FULL,COR,M,,,mlp,10," | tee -a $log_file
      if ( -f "$ds/$data_file_filename.match001.reject") then
         if ( ! -z "$ds/$data_file_filename.match001.reject") then
            echo "Error - aktualizace pole 856 na zaklade shody pole MLP - ident. cislo mlp selhalo u zaznamu:" | tee -a $log_file
            cat "$ds/$data_file_filename.match001.reject"
            cat "$ds/$data_file_filename.match001.reject" >>$log_file
         endif
      endif
      cp "$ds/$data_file_filename.match001" "$script_home_dir/data/$data_file_filename.match001"
      printf "\nPodle shody pole MLP - ident. cisla mlp aktualizovano pole 856 u `grep $ -c $alephe_scratch/$data_file_filename.match001.log` zaznamu. Najdes je v $script_home_dir/data/$data_file_filename.match001.\n\n" | tee -a $log_file
      printf "\nPodle shody pole MLP - ident. cisla mlp aktualizovano pole 856 u `grep $ -c $alephe_scratch/$data_file_filename.match001.log` zaznamu." >> $log_file4mail
   endif
endif
# 2 match - do nejakeho error a to posli mailem
if ( -f "$ds/$data_file_filename.err001") then
   if ( ! -z "$ds/$data_file_filename.err001") then
      printf "\nWarning - u nasledujicich zanamu doslo k vice nez 1 shode podle indent. cisla MLP, pole 001/MLP:\n" | tee -a $log_file
      cat "$ds/$data_file_filename.err001"
      cat "$ds/$data_file_filename.err001" >>$log_file
   endif
endif
# 0 match - pokracuje

#b] mapovani proti 015 - cislo CNB
if ( -f "$ds/$data_file_filename.tmp.nomatch001" ) then
   if ( -z "$ds/$data_file_filename.tmp.nomatch001" ) then
      echo "Vse namapovano a importovano, nic dale nezbyva" | tee -a $log_file
      goto end
   endif
endif
mv -v "$ds/$data_file_filename.tmp.nomatch001" "$ds/$data_file_filename.seq"
csh -f $aleph_proc/p_manage_36 "$bib_base,$data_file_filename.seq,$data_file_filename.tmp.nomatch015,$data_file_filename.match015,$data_file_filename.err015,CNB," | tee -a $log_file
# 1 match - aktualizace poli 856 a pridani pole BAS
if ( -f "$ds/$data_file_filename.match015") then
   if ( ! -z "$ds/$data_file_filename.match015") then
      printf "\nV katalogu nalezeno `awk '{print $1;}' $ds/$data_file_filename.match015 | sort -u | grep $ -c` zaznamu se shodnym cislem CNB, aktualizuje se u nich pole 856.\ pole BAS s hodnotou $bas_field_value\n" | tee -a $log_file
      #pokud tam bude jine 856 nez mlp tak by se smazalo, proto nejdriv print03, cele to poskladat a pak importovat
      awk '{print $1;}' "$ds/$data_file_filename.match015" | sort -u | sed 's/$/@@@/' | sed "s/@@@/$bib_base/" >$alephe_scratch/mlp015.sys
      csh -f $aleph_proc/p_print_03 "$bib_base,mlp015.sys,856##,,,,,,,,mlp015.856,A,,,,N,"
      grep -v 'mlp.cz' "$ds/mlp015.856" >>"$ds/$data_file_filename.match015"
      awk '{print $1" BAS   L $$a@@@@@";}' "$ds/mlp015.856" | sed "s/@@@@@/bas_field_value/" >>"$ds/$data_file_filename.match015"
      mv -v "$ds/$data_file_filename.match015" "$ds/$data_file_filename.match015bas_field_value/" >>"$ds/$data_file_filename.match015"
      mv -v "$ds/$data_file_filename.match015" "$ds/$data_file_filename.match015.tmp"
      sort "$ds/$data_file_filename.match015.tmp" >"$ds/$data_file_filename.match015"
      sort "$ds/$data_file_filename.match015.tmp" >"$alephe_scratch/$data_file_filename.match015"
      rm -f "$ds/$data_file_filename.match015.tmp"
      #import
      csh -f $aleph_proc/p_manage_18 "$bib_base,$data_file_filename.match015,$data_file_filename.match015.reject,$data_file_filename.match015.log,OLD,MLPEB,,FULL,COR,M,,,mlp,10," | tee -a $log_file
      if ( -f "$ds/$data_file_filename.match015.reject") then
         if ( ! -z "$ds/$data_file_filename.match015.reject") then
            echo "Error - aktualizace pole 856 na zaklade shody pole cisla CNB selhalo u zaznamu:" | tee -a $log_file
            cat "$ds/$data_file_filename.match015.reject"
            cat "$ds/$data_file_filename.match015.reject" >>$log_file
         endif
      endif
      cp "$ds/$data_file_filename.match015" "$script_home_dir/data/$data_file_filename.match015"
      printf "\nPodle shody cisla CNB (pole 015) aktualizovano pole 856 BAS u `grep $ -c $alephe_scratch/$data_file_filename.match015.log` zaznamu. Najdes je v $script_home_dir/data/$data_file_filename.match015.\n\n" | tee -a $log_file
      printf "\nPodle shody cisla CNB (pole 015) aktualizovano pole 856 BAS u `grep $ -c $alephe_scratch/$data_file_filename.match015.log` zaznamu." >> $log_file4mail
   endif
endif
# 2 match - do nejakeho error a to posli mailem
if ( -f "$ds/$data_file_filename.err015") then
   if ( ! -z "$ds/$data_file_filename.err015") then
      printf "\nWarning - u nasledujicich zanamu doslo k vice nez 1 shode podle cisla CNB, pole 015:\n" | tee -a $log_file
      cat "$ds/$data_file_filename.err015"
      cat "$ds/$data_file_filename.err015" >>$log_file
   endif
endif
# 0 match - pokracuje

#c] mapovani proti ISNB - pole 020
if ( -f "$ds/$data_file_filename.tmp.nomatch015" ) then
   if ( -z "$ds/$data_file_filename.tmp.nomatch015" ) then
      echo "Vse namapovano a importovano, nic dale nezbyva" | tee -a $log_file
      goto end
   endif
endif
mv -v "$ds/$data_file_filename.tmp.nomatch015" "$ds/$data_file_filename.seq"
csh -f $aleph_proc/p_manage_36 "$bib_base,$data_file_filename.seq,$data_file_filename.tmp.nomatch020,$data_file_filename.match020,$data_file_filename.err020,ISBN," | tee -a $log_file
# 1 match - aktualizace poli 856 a pridani pole BAS
if ( -f "$ds/$data_file_filename.match020") then
   if ( ! -z "$ds/$data_file_filename.match020") then
      printf "\nV katalogu nalezeno `awk '{print $1;}' $ds/$data_file_filename.match020 | sort -u | grep $ -c` zaznamu s jednim shodnym ISBN, aktualizuje se u nich pole 856 a pole BAS s hodnotou $bas_field_value\n" | tee -a $log_file
      #pokud tam bude jine 856 nez mlp tak by se smazalo, proto nejdriv print03, cele to poskladat a pak importovat
      awk '{print $1;}' "$ds/$data_file_filename.match020" | sort -u | sed 's/$/@@@/' | sed "s/@@@/$bib_base/" >$alephe_scratch/mlp020.sys
      csh -f $aleph_proc/p_print_03 "$bib_base,mlp020.sys,856##,,,,,,,,mlp020.856,A,,,,N,"
      grep -v 'mlp.cz' "$ds/mlp020.856" >>"$ds/$data_file_filename.match020"
      awk '{print $1" BAS   L $$a@@@@@";}' "$ds/mlp020.856" | sed "s/@@@@@/bas_field_value/" >>"$ds/$data_file_filename.match020"
      mv -v "$ds/$data_file_filename.match020" "$ds/$data_file_filename.match020bas_field_value/" >>"$ds/$data_file_filename.match020"
      mv -v "$ds/$data_file_filename.match020" "$ds/$data_file_filename.match020.tmp"
      sort "$ds/$data_file_filename.match020.tmp" >"$ds/$data_file_filename.match020"
      sort "$ds/$data_file_filename.match020.tmp" >"$alephe_scratch/$data_file_filename.match020"
      rm -f "$ds/$data_file_filename.match020.tmp"
      #import
      csh -f $aleph_proc/p_manage_18 "$bib_base,$data_file_filename.match020,$data_file_filename.match020.reject,$data_file_filename.match020.log,OLD,MLPEB,,FULL,COR,M,,,mlp,10," | tee -a $log_file
      if ( -f "$ds/$data_file_filename.match020.reject") then
         if ( ! -z "$ds/$data_file_filename.match020.reject") then
            echo "Error - aktualizace pole 856 na zaklade shody ISBN selhalo u zaznamu:" | tee -a $log_file
            cat "$ds/$data_file_filename.match020.reject"
            cat "$ds/$data_file_filename.match020.reject" >>$log_file
         endif
      endif
      cp "$ds/$data_file_filename.match020" "$script_home_dir/data/$data_file_filename.match020"
      printf "\nPodle shody ISBN (pole 020) aktualizovano pole 856 a BAS u `grep $ -c $alephe_scratch/$data_file_filename.match020.log` zaznamu. Najdes je v $script_home_dir/data/$data_file_filename.match020.\n\n" | tee -a $log_file
      printf "\nPodle shody ISBN (pole 020) aktualizovano pole 856 a BAS u `grep $ -c $alephe_scratch/$data_file_filename.match020.log` zaznamu.\nJedna se o zaznamy:\n" >>$log_file4mail
      egrep "^......... 245|856" $script_home_dir/data/$data_file_filename.match020 >>$log_file4mail
      echo >>$log_file4mail
   endif
endif
# 2 match - do nejakeho error a to posli mailem
if ( -f "$ds/$data_file_filename.err020") then
   if ( ! -z "$ds/$data_file_filename.err020") then
      printf "\nWarning - u nasledujicich zanamu doslo k vice nez 1 shode podle ISBN, pole 020:\n" | tee -a $log_file
      cat "$ds/$data_file_filename.err020"
      cat "$ds/$data_file_filename.err020" >>$log_file
   endif
endif


# 0 match - pokracuje plny import celych zaznamu
if ( -f "$ds/$data_file_filename.tmp.nomatch020" ) then
   if ( -z "$ds/$data_file_filename.tmp.nomatch020" ) then
      echo "Vse namapovano a importovano, nic dale nezbyva" | tee -a $log_file
      goto end
   endif
endif
mv -v "$ds/$data_file_filename.tmp.nomatch020" "$ds/$data_file_filename.new"
printf "\nZbyva `awk '{print $1;}' $ds/$data_file_filename.seq | sort -u | grep $ -c` k uplnemu importu vcetne bibliogr. zaznamu.\n\n" | tee -a $log_file
awk -v bsv="$bas_field_value" '{ if ($2=="LDR") { print $0"\n"$1" BAS   L $$a"bsv;} else { print $0; } }' <$ds/$data_file_filename.new >$ds/$data_file_filename.new.tmp
mv $ds/$data_file_filename.new.tmp $ds/$data_file_filename.new
csh -f $aleph_proc/p_manage_18 "$bib_base,$data_file_filename.new,$data_file_filename.new.reject,$data_file_filename.new.log,NEW,MLPEB,,FULL,APP,M,,,mlp,10," | tee -a $log_file
if ( -f "$ds/$data_file_filename.new.reject") then
   if ( ! -z "$ds/$data_file_filename.new.reject") then
      echo "Error - uplny import vcetne biblio zaznamu selhalo u zaznamu:" | tee -a $log_file
      cat "$ds/$data_file_filename.new.reject"
      cat "$ds/$data_file_filename.new.reject" >>$log_file
   endif
endif
cp "$ds/$data_file_filename.new" "$script_home_dir/data/$data_file_filename.new"
printf "\nImportovano `grep $ -c $alephe_scratch/$data_file_filename.new.log` kompletnich bibliografickych zaznamu. Najdes je v $script_home_dir/data/$data_file_filename.new\n\n" | tee -a $log_file
printf "Jedna se o sysna:\n" | tee -a $log_file
cat "$alephe_scratch/$data_file_filename.new.log" | tee -a $log_file
printf "\nNove importovano `grep $ -c $alephe_scratch/$data_file_filename.new.log` kompletnich bibliografickych zaznamu.\n Jsou v priloze nebo je najdete pomoci CCL dotazu: wbs=MKPfree and wct=$today2.\n" >>$log_file4mail
      


end:
echo "Hotovo - `date`" | tee -a $log_file
date +"%Y-%m-%d" >$script_home_dir/eknihy_mlp_update.timestamp
date +"%Y-%m-%d" >$alephe_scratch/eknihy_mlp_update.timestamp
if ( "$admin_email" !=  "") then
   echo "Posilam report na $admin_email"
   if ( -f "$script_home_dir/data/$data_file_filename.new" ) then
      cat $log_file4mail | mutt -s  "E-knihy MLP (MK v Praze) import probehl, nove zaznamy" "$admin_email" -a $log_file -a "$script_home_dir/data/$data_file_filename.new" 
   else
      cat $log_file4mail | mutt -s  "E-knihy MLP (MK v Praze) import probehl" "$admin_email" -a "$log_file"
   endif
endif
if ( "$cataloger_email" !=  "") then
   echo "Posilam report na $cataloger_email"
   cp "$script_home_dir/data/$data_file_filename.new" "$script_home_dir/data/$data_file_filename.new.txt"
   if ( -f "$script_home_dir/data/$data_file_filename.new" ) then
      cat $log_file4mail | mutt -s  "E-knihy MLP (MK v Praze) import probehl, nove zaznamy" "$cataloger_email"  -a "$script_home_dir/data/$data_file_filename.new.txt" 
   else
      cat $log_file4mail | mutt -s  "E-knihy MLP (MK v Praze) import probehl" "$cataloger_email" 
   endif
   rm -f "$script_home_dir/data/$data_file_filename.new.txt"
endif
exit 0

error:
echo "Fatal error - exiting - `date`" | tee -a $log_file
echo "Posilam report na $admin_email"
echo "" | mutt -s "E-knihy MLP (MK v Praze) import fatal error" "$admin_email" -a "$log_file" 
exit 1

