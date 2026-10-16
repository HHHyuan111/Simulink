function valid=sless_input_block(diag,mode)
%#codegen
valid=mode(1)==0||mode(2)==0||all(diag(7:9)>.5);
end
