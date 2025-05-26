import psycopg2

#connect to postgres database
conn = psycopg2.connect(host='localhost',
                       dbname='test_task',
                       user='postgres',
                       password='postgres12345',
                       port='5432')
cur = conn.cursor()

#create table if doesn't exist, additional event_id unique column for debugging if needed
cur.execute("""CREATE TABLE IF NOT EXISTS events(event_id SERIAL PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    revenue FLOAT NOT NULL,
    event_name VARCHAR(50) NOT NULL)""")

conn.commit()

#list of csv files
csv_files = ['file_{:02}.csv'.format(i) for i in range(1, 11)]

#load files and insert into table
for file in csv_files:
    with open(file, 'r') as f:
        #skip header row
        next(f)
        #insert data into correct columns, excluding auto-generated event_id with "columns=(...)"
        cur.copy_from(f, 'events', sep=',', columns=('user_id', 'created_at', 'revenue', 'event_name'))

#commit changes
conn.commit()
#close connection
cur.close()
conn.close()