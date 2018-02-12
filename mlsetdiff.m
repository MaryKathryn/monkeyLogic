function C = mlsetdiff(A,B)

if isempty(B), C = A; return, end

if iscell(A)
    row = strcmp(A,B{1});
    for m=2:length(B)
        row = row|strcmp(A,B{m});
    end
elseif isnumeric(A)
    row = B(1)==A;
    for m=2:length(B)
        row = row|B(m)==A;
    end
else
    error('Input is not numeric or cell arrays of strings');
end

C = A(~row);

end
