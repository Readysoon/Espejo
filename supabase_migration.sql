-- Neue Felder in conversations hinzufügen
alter table conversations add column if not exists subtitle text;
alter table conversations add column if not exists summary text;
alter table conversations add column if not exists date date default current_date;
alter table conversations add column if not exists steps integer;
alter table conversations add column if not exists location text;
alter table conversations add column if not exists weather text;
