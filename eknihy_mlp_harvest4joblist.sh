#!/bin/sh
den_spousteni="08"
cesta_k_skriptum='/exlibris/aleph/matyas/eknihy_mlp'

den=`date +%d`
datum=`date +"%Y%m%d"`

if [ "$den" == "$den_spousteni" ]; then
   #dohledani posledniho updatu
   if [ -f "$cesta_k_skriptum/eknihy_mlp_update.timestamp" ]; then
      echo "Posledni update probehl `cat $cesta_k_skriptum/eknihy_mlp_update.timestamp`"
      dat_akt=`cat $cesta_k_skriptum/eknihy_mlp_update.timestamp`
   else
      if [ -f $alephe_scratch/eknihy_mlp_update.timestamp ]; then
         echo "Posledni update probehl `cat $alephe_scratch/eknihy_mlp_update.timestamp`"
         dat_akt=`cat $alephe_scratch/eknihy_mlp_update.timestamp`
      else
         echo "Datum posledniho updatu nenalezen, pouzivam 1 mesic zpet: "`date +"%Y-%m-%d" -d '1 month ago'`
         dat_akt=`date +"%Y-%m-%d" -d '1 month ago'`
      fi
   fi
   echo "spoustim aktualizaci $cesta_k_skriptum/eknihy_mlp_harvest.csh akt $dat_akt"
   $cesta_k_skriptum/eknihy_mlp_harvest.csh akt $dat_akt
else
   echo "Spousti se $den_spousteni den v mesici, dnes nic"
fi
