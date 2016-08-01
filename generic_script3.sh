# umask 000
# . /u/.setup
rm data
for STORE in `cat /u/data/storelist/stores.update`
do
    echo ""
    date
    echo $STORE

  echo "Checking $STORE"
  ping -q -c1 hst$STORE
  if [[ $? -ne 0 ]];then
    echo "$STORE is off of the network!!!!!!"
  else

    while true
    do
          dbaccess //hst$STORE/store pull.sql
             RESULT=$?

       if [[ RESULT -eq 0 ]]
       then
          echo "$STORE *** SUCCESS ***"
cat pull_data.unl >> data
          break
       else
          echo "$STORE ### FAILED ###"
          sleep 15
          continue
       fi


    done
  fi

done

