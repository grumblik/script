#!/usr/bin/env python3

### Test script
### Insert date sequence into MySQL
###

from datetime import date, timedelta

import datetime
import MySQLdb
import random

db = MySQLdb.connect(host="localhost",    # your host, usually localhost
                     user="root",         # your username
                     passwd="ghjnjc",     # your password
                     db="date_test")      # name of the data base
cursor = db.cursor()                      # open connetcion to db

start_date = datetime.datetime(2019,1,1)  # Date begin on this
delta = timedelta(minutes=30)

for o_id in range(1, 100000):
#  print (o_id)                                                 # Debug output to stdout
#  print ("=================================================")  #
  start_date = datetime.datetime(2019,1,1)
  db.commit()
  for days_count in range(1, 120):        # 120 days
    for intraday in range(0, 48):         # 48 bits on 30 minutes in day
      status = random.randint(0,1)        # random status
      result = cursor.execute('insert into brone(o_id,date,status) VALUES(%s,%s,%s);', (o_id,start_date.strftime('%Y-%m-%d %H:%M:%S'),status))
      start_date += delta                 # increment date
