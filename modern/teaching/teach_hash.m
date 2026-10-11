function result=teach_hash(path)
fid=fopen(path,'rb');data=fread(fid,Inf,'*uint8');fclose(fid);
md=java.security.MessageDigest.getInstance('SHA-256');md.update(data);
result=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
