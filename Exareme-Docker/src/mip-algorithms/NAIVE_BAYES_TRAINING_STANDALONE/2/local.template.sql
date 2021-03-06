requirevars 'defaultDB' 'prv_output_global_tbl' 'x' 'y';
attach database '%{defaultDB}' as defaultDB;

drop table if exists localmetadatatbl;
create temp table localmetadatatbl as
select * from %{prv_output_global_tbl};

--For each categorical column x: segment the data by the distinct values of each column, and by the class values, and then count the rows.
drop table if exists local_counts;
create temp table local_counts(colname text, val text, classval text, S1 real, S2 real, quantity int);

--For each categorical column x: segment the data by the distinct values of each column, and by the class values, and then count the rows.
var 'categoricalcolumns' from select case when count(*)==0 then '' else group_concat(code) end from localmetadatatbl where categorical=1;
var 'categorical_localcounts' from select create_complex_query("","
insert into local_counts
select '?' as colname, ? as val, %{y} as classval, 'NA' as S1, 'NA' as S2, count(?) as quantity
from defaultDB.local_trainingset
group by colname,%{y},?;", "" , "" , '%{categoricalcolumns}');
%{categorical_localcounts};

-- For each non-categorical column x: segment the data by the class values, and then compute the local mean and variance of x in each class.--
var 'non_categoricalcolumns' from select case when count(*)==0 then '' else group_concat(code) end from localmetadatatbl where categorical<>1 ;
var 'non_categorical_localcounts' from select create_complex_query("","
insert into local_counts
select '?' as colname, 'NA' as val, %{y} as classval, sum(?) as S1, sum( ?*?) as S2, count(?)
from defaultDB.local_trainingset
group by colname,%{y};", "" , "" , '%{non_categoricalcolumns}');
%{non_categorical_localcounts};

select * from local_counts;
