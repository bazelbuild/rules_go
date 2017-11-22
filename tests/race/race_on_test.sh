OUTPUT="$(tests/race/race_on_tester 2>&1)"
if [ $? -eq 0 ]; then
  echo success
  echo "Expected failure, got success"
  exit 1
fi
if [[ $OUTPUT != *"WARNING: DATA RACE"* ]]; then
  echo "Expected WARNING: DATA RACE and it was not present"
  exit 1
fi
exit 0