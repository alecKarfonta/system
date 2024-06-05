

# Show tables
```sql
\dt
```

**Describe table**
```sql
SELECT column_name, data_type, character_maximum_length FROM information_schema.columns WHERE table_name = 'entity';
```


# Connect to database
```bash
psql -h cbc2-cb-postgres-dev.cbrpp0ztnsns.us-gov-west-1.rds.amazonaws.com -d commsbroker -U cbdevpostgres
```
```bash
psql -h cbc2-cb-postgres-dev-geomesa.cbrpp0ztnsns.us-gov-west-1.rds.amazonaws.com  -d commsbroker -U cbdevpostgres
```

# Convert ppk to pem



# Export sample of data
```bash
\COPY (SELECT * FROM entity LIMIT 10) TO 'entity_sample.csv' (format csv, delimiter ';');
```


# Pull file from server
```bash
scp -i C:\Users\1610529972\id_rsa ec2-user@10.2.16.90:/home/ec2-user/entity_sample.csv  C:\Users\1610529972\
```