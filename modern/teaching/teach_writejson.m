function teach_writejson(path,data)
fid=fopen(path,'w','n','UTF-8');guard=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(data,PrettyPrint=true));
end
