#!/usr/bin/env python3

### Script for select random date from DB

from datetime import date, timedelta

import datetime
import MySQLdb
import random
import time

db = MySQLdb.connect(host="localhost",    # your host, usually localhost
                     user="root",         # your username
                     passwd="ghjnjc",     # your password
                     db="date_test")      # name of the data base
cursor = db.cursor()

random = random.randint(1,30000)
delta = timedelta(minutes=30)

random_date = datetime.datetime(2019,1,1) + delta*random
start_time = time.time()
result = cursor.execute('select count(o_id) from brone where status = 1 and date = %s;', (random_date.strftime('%Y-%m-%d %H:%M:%S'),))
print("--- %s seconds ---" % (time.time() - start_time))
print (result)
