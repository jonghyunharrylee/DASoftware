classdef CSKF < DA
    % Created by Judith Li 3/27
    % Modified by Judith Li 3/30
    properties
        N; % number of basis
        A; % orthorgonal basis selected using DCT or rSVD
        C; % compressed covariance of P
        V; % compressed covariance of Q
        R; % meausurement error covariance
        FA; % Jacobian matrix vector for f(x)
        HA; % Jacobian matrix vector for h(x)
        BasisType; % DCT or rSVD
        P; % full covariance (for testing purpose)
        theta; % hyperparameter controlling data fitting
        variance;
        % TODO: extension for augmented state
    end
    methods
        function obj = CSKF(param,fw)
            obj.N = param.N;
            obj.BasisType = param.BasisType;
            obj.kernel = param.kernel;
            obj.nt = param.nt;
            obj.m =  fw.m;
            obj.n =  fw.n;
            % initialize state using fw.getx
            rng(101);
            obj.x =  fw.getx();
            obj.A =  zeros(obj.m,obj.N);%getBasis(obj,fw);
            obj.C =  zeros(obj.N,obj.N);%getCompCov(obj,fw);
            obj.V =  zeros(size(obj.C)); % no Q
            %             obj.V = getCompCov(obj.A,obj.kernel); % TODO: add Q
            obj.R =  param.obsstd.*eye(fw.n,fw.n);
            obj.P =  obj.A*obj.C*obj.A'; % for test
            obj.variance = diag(obj.P);
        end
        
        function predict(obj,fw)
            % Propagate state x and its covariance P
                fx = fw.f(obj.x);    % note that it changes fw
                obj.FA = obj.getFA(@fw.f,obj.A,obj.x,fx);
                U = obj.A'* obj.FA;
                obj.C = U*obj.C*U' + obj.V;
            obj.t_forecast = obj.t_forecast + 1;
            obj.P = obj.A*obj.C*obj.A'; % for test
            obj.variance = diag(obj.P);
            obj.x = fx;
        end
        
        function update(obj,fw)
            % update x using measurement z
            hx = fw.h(obj.x); %BUG: hx is not a structure?
            obj.HA = obj.getFA(@fw.h,obj.A,obj.x,hx);
%             obj.HA = getHA(obj,fw);
            HPHT = obj.HA*obj.C*obj.HA';%nN^2 + n^2N
            AA = HPHT + obj.R; % 2nN^2, innovation matrix
            BB = obj.HA*obj.C;
            XX = AA\BB;
            obj.K = obj.A*XX';
            obj.x.vec = obj.x.vec + obj.K*(fw.zt.vec-hx.vec);
            obj.C = (eye(size(obj.C))-XX'*obj.HA)*obj.C;%Nmn+ N^2 + N^3
            obj.t_assim = obj.t_assim + 1;
            obj.P = obj.A*obj.C*obj.A'; % for test
            obj.variance = diag(obj.P);
        end
        
        function FA = getFA(obj,f,A,x,fx)
            % compute Jacobian matrix product
            % input:
            %   f: function handle
            %       it Jacobian F is size of n x m
            %   A:  matrix of size m x N
            %       matrix multiplier
            %   x:  structure, contain .vec
            %       input
            %   fx: forecast of size n x 1
%             FA = fw.F*obj.A; % hard coding for Saetrom
            N = size(A,2);
            n = size(fx.vec,1);
            FA = zeros(n,N);
            delta = 1e-8;
            a = delta*norm(x.vec);
            if a <=0
                a = delta;
                fprintf('FA: perturbation factor a is smaller than zero, change it to %d\n',delta);
            end
            for i = 1:N
                u = A(:,i);
                b = a/norm(u);
                x1 = x;
                x1.vec = x.vec + b*u;
                fx1 = f(x1);
                FA(:,i) = (fx1.vec-fx.vec)/b;
            end
            
        end
        
        function HA = getHA(obj,fw)
            HA = fw.H*obj.A; % hard coding for Saetrom
        end
        
        function A = getBasis(obj,loc,kernel)
            % generate a basis for a covariance matrix defined through a kernel
            P0 = common.getQ(loc,kernel);
            switch obj.BasisType
                case 'DCT'
                    error('to be added');
                case 'rSVD'
                    [A,~,~] = common.RandomizedCondSVD(P0,obj.N,1); % hard code q = 1 for smooth spectrum
                case 'SVD'
                    [A,~,~] = svd(P0);
                    A = A(:,1:obj.N);
                otherwise
                    error('not a valid basis type');
            end
        end
        
        function C = getCompCov(obj,loc,kernel,A)
            % hard code, use mxBBFMM2D instead
            P0 = common.getQ(loc,kernel);
            C = A'* P0 * A;
        end

        function obj = addRegularization(obj,param)
            if isfield(param,'theta')
                obj.theta = param.theta;
                obj.C = obj.theta(1)*obj.theta(2)*obj.C;
                obj.V = obj.theta(1)*obj.theta(2)*obj.V;
                obj.R = obj.theta(2)*obj.R;
                obj.variance = obj.theta(1)*obj.theta(2)*obj.variance;
            end
        end
        
    end
end
