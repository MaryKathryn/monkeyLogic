function varargout = projective_transform(cmd,varargin)
    switch cmd
        case 'calculate'
            p = varargin{1};
            q = varargin{2};
            varargout{1} = calculate_transform(p,q);

        case 'convert'
            tform = varargin{1};
            varargout{1} = convert_tform(tform);

        case 'forward'
            tform = varargin{1};
            p = varargin{2};
            varargout{1} = tform.forward_fcn(tform,p);
        case 'inverse'
            tform = varargin{1};
            q = varargin{2};
            varargout{1} = tform.inverse_fcn(tform,q);
            
        otherwise
            error('mgl2dtransform:UnknownCmd','Unknown command!!!');
    end
end

% projective transformation
% http://homepages.inf.ed.ac.uk/rbf/CVonline/LOCAL_COPIES/BEARDSLEY/node3.html
function tform = calculate_transform(p,q)
    m = size(p,1);
    z = zeros(m,1);
    o = ones(m,1);
    p1 = p(:,1);
    p2 = p(:,2);
    q1 = q(:,1);
    q2 = q(:,2);

    M = [p1 p2 o z z z -p1.*q1 -p2.*q1; z z z p1 p2 o -p1.*q2 -p2.*q2];
    if rank(M)<8, error('projective_transform:LowMatrixDimension','The equation matrix is insolvable!!!'); end
    T = reshape([M \ [q1; q2]; 1],3,3);
    
    tform.ndims_in = 2;
    tform.ndims_out = 2;
    tform.forward_fcn = @fwd_projective;
    tform.inverse_fcn = @inv_projective;
    tform.tdata.T = T;
    tform.tdata.Tinv = inv(T);
end
function q = fwd_projective(tform,p)
    q = [p ones(size(p,1),1)] * tform.tdata.T;
    q = q(:,1:2) ./ repmat(q(:,3),1,2);
end
function p = inv_projective(tform,q)
    p = [q ones(size(q,1),1)] * tform.tdata.Tinv;
    p = p(:,1:2) ./ repmat(p(:,3),1,2);
end

function tform = convert_tform(tform)
    if isempty(tform), return, end
    
    tform.forward_fcn = @fwd_projective;
    tform.inverse_fcn = @inv_projective;

    n = length(tform.tdata);
    if 1 < n
        for m=1:n
            tform.tdata(m).forward_fcn = @fwd_projective;
            tform.tdata(m).inverse_fcn = @inv_projective;
        end
    end
end