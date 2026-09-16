function results = projectile_physics(params)
%PROJECTILE_PHYSICS Simulate a projectile until its first ground impact.
%   Uses an analytic point-mass solution and adaptive ODE45 integration for
%   quadratic drag. Returned samples always end exactly at y = 0.

arguments
    params (1,1) struct
end

required = {'g','dt','model','theta','h0','v0'};
for i = 1:numel(required)
    if ~isfield(params,required{i})
        error('projectile:MissingParameter', ...
            'Missing required parameter "%s".',required{i});
    end
end

validateScalar(params.g,     'g',     0,   Inf, false, true);
validateScalar(params.dt,    'dt',    0,   0.5, false, true);
validateScalar(params.theta, 'theta', 0,   90,  true,  true);
validateScalar(params.h0,    'h0',    0,   Inf, true,  true);
validateScalar(params.v0,    'v0',    0,   Inf, true,  true);

model = validateChoice(params.model,{'point','sphere'},'model');
g = params.g;
dt = params.dt;
theta = deg2rad(params.theta);
vx0 = params.v0*cos(theta);
vy0 = params.v0*sin(theta);
state0 = [0; params.h0; vx0; vy0];

maxTime = getOptionalLimit(params,'maxTime',3600);
maxSteps = getOptionalLimit(params,'maxSteps',250000);
if maxSteps ~= floor(maxSteps)
    error('projectile:InvalidParameter','maxSteps must be an integer.');
end

% An object already on the ground and not moving upward is not airborne.
if params.h0 == 0 && vy0 <= 0
    results = packageResults(0,state0,model,params,0,0);
    return;
end

switch model
    case 'point'
        discriminant = vy0^2 + 2*g*params.h0;
        tImpact = (vy0 + sqrt(discriminant))/g;
        if tImpact > maxTime
            error('projectile:TimeLimit', ...
                'Predicted flight time %.3g s exceeds the %.3g s safety limit.', ...
                tImpact,maxTime);
        end

        nRegular = floor(tImpact/dt);
        if nRegular + 2 > maxSteps
            error('projectile:StepLimit', ...
                'This run would require more than %d samples. Increase dt or reduce the launch scale.', ...
                maxSteps);
        end

        T = (0:nRegular)*dt;
        if isempty(T) || abs(T(end)-tImpact) > 16*eps(max(1,tImpact))
            T(end+1) = tImpact;
        else
            T(end) = tImpact;
        end

        X = vx0*T;
        Y = params.h0 + vy0*T - 0.5*g*T.^2;
        VX = vx0 + zeros(size(T));
        VY = vy0 - g*T;
        Y(end) = 0;
        states = [X(:),Y(:),VX(:),VY(:)];
        tApex = max(0,vy0/g);
        hApex = params.h0 + vy0*tApex - 0.5*g*tApex^2;
        results = packageResults(T(:),states,model,params,tApex,hApex);

    case 'sphere'
        sphereFields = {'Cd','rho','m','geometry'};
        for i = 1:numel(sphereFields)
            if ~isfield(params,sphereFields{i})
                error('projectile:MissingParameter', ...
                    'Missing required sphere parameter "%s".',sphereFields{i});
            end
        end
        validateScalar(params.Cd, 'Cd',  0, Inf, true, true);
        validateScalar(params.rho,'rho', 0, Inf, true, true);
        validateScalar(params.m,  'm',   0, Inf, false,true);
        geometry = validateChoice(params.geometry,{'radius','area'},'geometry');
        if strcmp(geometry,'radius')
            if ~isfield(params,'radius')
                error('projectile:MissingParameter','Missing required parameter "radius".');
            end
            validateScalar(params.radius,'radius',0,Inf,false,true);
            area = pi*params.radius^2;
        else
            if ~isfield(params,'area')
                error('projectile:MissingParameter','Missing required parameter "area".');
            end
            validateScalar(params.area,'area',0,Inf,false,true);
            area = params.area;
        end

        % Count actual output, including the initial sample. Refine=1 makes
        % each accepted step produce one sample, so the callback can stop
        % before another step would exceed the storage budget.
        outputCount = 1;
        budgetReached = false;
        dragFactor = 0.5*params.Cd*params.rho*area/params.m;
        options = odeset('RelTol',1e-8,'AbsTol',1e-10, ...
            'MaxStep',dt,'Events',@events,'Refine',1, ...
            'OutputFcn',@limitOutput);
        stiffnessIndex = dragFactor*max(params.v0,1)*dt;
        if stiffnessIndex > 1
            odeSolver = @ode15s;
        else
            odeSolver = @ode45;
        end
        [T,states,TE,YE,IE] = odeSolver(@dynamics,[0 maxTime],state0,options);

        impactEvent = find(IE == 1,1,'last');
        if isempty(impactEvent)
            if budgetReached
                error('projectile:StepLimit', ...
                    'The adaptive solver reached the %d-sample limit before impact.',maxSteps);
            end
            error('projectile:NoImpact', ...
                'No ground impact was found within %.3g s. Reduce the drag scale or increase maxTime.', ...
                maxTime);
        end
        if size(states,1) > maxSteps
            error('projectile:StepLimit','The adaptive solver exceeded %d stored steps.',maxSteps);
        end
        if any(~isfinite(states),'all') || any(~isfinite(T))
            error('projectile:NonFiniteState','The solver produced a non-finite state.');
        end

        impactTime = TE(impactEvent);
        impactState = YE(impactEvent,:);
        if abs(T(end)-impactTime) > 16*eps(max(1,impactTime))
            if numel(T) >= maxSteps
                error('projectile:StepLimit','No sample budget remains for the impact state.');
            end
            T(end+1,1) = impactTime;
            states(end+1,:) = impactState;
        else
            T(end) = impactTime;
            states(end,:) = impactState;
        end
        states(end,2) = 0;

        apexEvent = find(IE == 2 & TE >= 0,1,'first');
        if isempty(apexEvent)
            [hApex,idx] = max(states(:,2));
            tApex = T(idx);
        else
            tApex = TE(apexEvent);
            hApex = YE(apexEvent,2);
        end
        results = packageResults(T,states,model,params,tApex,hApex);
end

    function stop = limitOutput(t,~,flag)
        stop = false;
        if strcmp(flag,'init')
            if maxSteps < 2
                error('projectile:StepLimit', ...
                    'An airborne trajectory requires at least two samples.');
            end
        elseif isempty(flag)
            outputCount = outputCount + numel(t);
            budgetReached = outputCount >= maxSteps;
            stop = budgetReached;
        end
    end

    function ds = dynamics(~,s)
        speed = hypot(s(3),s(4));
        ds = [s(3); s(4); -dragFactor*speed*s(3); ...
            -g-dragFactor*speed*s(4)];
    end

    function [value,isTerminal,direction] = events(t,s)
        groundValue = s(2);
        if params.h0 == 0 && vy0 > 0 && t <= 1e-12
            groundValue = 1; % Ignore launch contact; detect later descent.
        end
        value = [groundValue; s(4)];
        isTerminal = [1; 0];
        direction = [-1; -1];
    end
end

function results = packageResults(T,states,model,params,tApex,hApex)
T = T(:).';
if size(states,1) ~= numel(T)
    states = states.';
end
results.X = states(:,1).';
results.Y = states(:,2).';
results.VX = states(:,3).';
results.VY = states(:,4).';
results.T = T;
results.model = model;
results.params = params;
results.apexTime = tApex;
results.maxHeight = hApex;
results.impactTime = T(end);
results.range = results.X(end);
results.impactSpeed = hypot(results.VX(end),results.VY(end));
results.impactAngle = atan2d(results.VY(end),results.VX(end));
results.landed = true;
end

function validateScalar(value,name,lower,upper,includeLower,includeUpper)
if ~(isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value))
    error('projectile:InvalidParameter','%s must be a finite real scalar.',name);
end
lowerOK = value > lower || (includeLower && value == lower);
upperOK = value < upper || (includeUpper && value == upper);
if ~(lowerOK && upperOK)
    leftBracket = pickBracket(includeLower,'[','(');
    rightBracket = pickBracket(includeUpper,']',')');
    error('projectile:InvalidParameter','%s must be in %s%g, %g%s.', ...
        name,leftBracket,lower,upper,rightBracket);
end
end

function value = getOptionalLimit(params,name,defaultValue)
if isfield(params,name)
    value = params.(name);
else
    value = defaultValue;
end
validateScalar(value,name,0,Inf,false,true);
end

function value = validateChoice(candidate,choices,name)
try
    value = validatestring(candidate,choices,mfilename,name);
catch
    error('projectile:InvalidParameter','%s must be one of: %s.',...
        name,strjoin(choices,', '));
end
end

function value = pickBracket(condition,a,b)
if condition, value = a; else, value = b; end
end
