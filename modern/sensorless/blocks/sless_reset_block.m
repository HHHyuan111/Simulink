function reset=sless_reset_block(ready,enabled)
%#codegen
reset=~ready||enabled==0;
end
