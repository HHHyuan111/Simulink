function [passed,count,failures]=compare_sensorless_n3_raw(first,second,names)
% Exact full-array comparison with one MAT deserialization in memory at a time.
% A private binary scratch file preserves native values; each read uses isequaln.
if nargin<3,names={};end
a=whos('-file',first);b=whos('-file',second);
if isempty(names),assert(isequal({a.name},{b.name}));names={a.name};end
here=fileparts(mfilename('fullpath'));scratch=fullfile(here,'.build');
if ~isfolder(scratch),mkdir(scratch);end
buffer=[tempname(scratch) '.bin'];fid=fopen(buffer,'w');assert(fid>=0);
clean=onCleanup(@()close_file(fid));
raw=load(first,names{:});meta=cell(numel(names),2);count=0;
for k=1:numel(names)
 p=raw.(names{k});assert(isa(p,'timeseries'));
 for j=1:2
  field='Time';if j==2,field='Data';end
  value=p.(field);assert(isreal(value)&&isnumeric_or_logical(value));
  type=class(value);storage=type;if strcmp(type,'logical'),storage='uint8';end
  meta{k,j}=struct('size',size(value),'class',type,'storage',storage,'count',numel(value));
  assert(fwrite(fid,value,storage)==numel(value));count=count+numel(value);
 end
end
clear raw p value clean;
fid=fopen(buffer,'r');assert(fid>=0);clean=onCleanup(@()close_file(fid));
raw=load(second,names{:});failures={};chunk=2^20;
for k=1:numel(names)
 q=raw.(names{k});assert(isa(q,'timeseries'));same=true;
 for j=1:2
  field='Time';if j==2,field='Data';end
  value=q.(field);m=meta{k,j};shape=isequal(size(value),m.size)&&strcmp(class(value),m.class);
  same=same&&shape;
  for begin=1:chunk:m.count
   n=min(chunk,m.count-begin+1);[expected,got]=fread(fid,n,['*' m.storage]);assert(got==n);
   if strcmp(m.class,'logical'),expected=logical(expected);end
   if shape,actual=value(begin:begin+n-1);same=same&&isequaln(expected,actual(:));end
  end
 end
 if ~same,failures{end+1}=names{k};end %#ok<AGROW>
end
assert(isempty(fread(fid,1,'uint8')));clear clean;delete(buffer);
passed=isempty(failures);
end

function yes=isnumeric_or_logical(value),yes=isnumeric(value)||islogical(value);end
function close_file(fid),fclose(fid);end
