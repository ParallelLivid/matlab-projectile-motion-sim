function tests = test_projectile_physics
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(projectRoot);
testCase.TestData.ProjectRoot = projectRoot;
end

function teardownOnce(testCase)
rmpath(testCase.TestData.ProjectRoot);
end

function testPointMassMatchesClosedForm(testCase)
p = pointParams();
p.dt = 0.5;
r = projectile_physics(p);
tExpected = 2*p.v0*sind(p.theta)/p.g;
xExpected = p.v0*cosd(p.theta)*tExpected;
hExpected = (p.v0*sind(p.theta))^2/(2*p.g);

verifyEqual(testCase,r.impactTime,tExpected,'AbsTol',1e-11);
verifyEqual(testCase,r.range,xExpected,'AbsTol',1e-9);
verifyEqual(testCase,r.maxHeight,hExpected,'AbsTol',1e-10);
verifyEqual(testCase,r.apexTime,tExpected/2,'AbsTol',1e-11);
verifyEqual(testCase,r.Y(end),0);
verifyEqual(testCase,r.impactAngle,-45,'AbsTol',1e-10);
end

function testElevatedPointMassMatchesClosedForm(testCase)
p = pointParams();
p.h0 = 120;
p.theta = 20;
r = projectile_physics(p);
vy = p.v0*sind(p.theta);
tExpected = (vy + sqrt(vy^2 + 2*p.g*p.h0))/p.g;
verifyEqual(testCase,r.impactTime,tExpected,'AbsTol',1e-11);
verifyEqual(testCase,r.Y(end),0);
verifyGreaterThan(testCase,r.impactSpeed,p.v0);
end

function testGroundContactIsImmediate(testCase)
p = pointParams();
p.theta = 0;
r = projectile_physics(p);
verifyEqual(testCase,r.T,0);
verifyEqual(testCase,r.X,0);
verifyEqual(testCase,numel(r.T),1);
end

function testZeroDragConvergesToPointMass(testCase)
p = pointParams();
point = projectile_physics(p);
p = dragParams();
p.Cd = 0;
drag = projectile_physics(p);
verifyEqual(testCase,drag.impactTime,point.impactTime,'AbsTol',1e-8);
verifyEqual(testCase,drag.range,point.range,'AbsTol',1e-7);
verifyEqual(testCase,drag.maxHeight,point.maxHeight,'AbsTol',1e-7);
end

function testDragTrajectoryHasPhysicalInvariants(testCase)
p = dragParams();
r = projectile_physics(p);
verifyTrue(testCase,all(isfinite([r.T r.X r.Y r.VX r.VY])));
verifyGreaterThan(testCase,diff(r.T),zeros(1,numel(r.T)-1));
verifyGreaterThanOrEqual(testCase,r.Y,-1e-10*ones(size(r.Y)));
verifyGreaterThanOrEqual(testCase,r.VX,-1e-10*ones(size(r.VX)));
verifyLessThan(testCase,r.range,projectile_physics(pointParams()).range);
verifyEqual(testCase,r.Y(end),0);
verifyLessThan(testCase,r.impactAngle,0);
end

function testInvalidInputsAreRejected(testCase)
p = pointParams();
p.g = NaN;
verifyError(testCase,@() projectile_physics(p),'projectile:InvalidParameter');

p = pointParams();
p.model = 'unknown';
verifyError(testCase,@() projectile_physics(p),'projectile:InvalidParameter');

p = dragParams();
p.m = 0;
verifyError(testCase,@() projectile_physics(p),'projectile:InvalidParameter');
end

function testSafetyLimitsAreEnforced(testCase)
p = pointParams();
p.v0 = 5000;
p.g = 0.01;
verifyError(testCase,@() projectile_physics(p),'projectile:TimeLimit');

p = pointParams();
p.maxSteps = 10;
verifyError(testCase,@() projectile_physics(p),'projectile:StepLimit');
end

function testExtremeDragFailsSafely(testCase)
p = dragParams();
p.dt = 0.5;
p.theta = 45;
p.h0 = 1;
p.v0 = 1000;
p.Cd = 2;
p.rho = 1000;
p.m = 0.001;
p.geometry = 'area';
p.area = 1;
p.maxTime = 1;
verifyError(testCase,@() projectile_physics(p),'projectile:NoImpact');
end

function testLongDragDropUsesConfiguredHorizon(testCase)
p = dragParams();
p.h0 = 100;
p.v0 = 0;
p.Cd = 2;
p.rho = 1000;
p.geometry = 'area';
p.area = 1;
p.dt = 0.5;
p.maxTime = 1100;
r = projectile_physics(p);
% Exact vertical quadratic-drag drop, evaluated without overflowing cosh.
k = p.rho*p.Cd*p.area/(2*p.m);
expected = (k*p.h0 + log(1+sqrt(1-exp(-2*k*p.h0))))/sqrt(p.g*k);
verifyEqual(testCase,r.impactTime,expected,'AbsTol',1e-3);
verifyEqual(testCase,r.Y(end),0);
p.maxTime = 1000;
verifyError(testCase,@() projectile_physics(p),'projectile:NoImpact');
end

function testBudgetCountsActualFlight(testCase)
p = dragParams();
p.Cd = 0;
p.maxSteps = 5000;
r = projectile_physics(p);
verifyEqual(testCase,r.impactTime,2*p.v0*sind(p.theta)/p.g,'AbsTol',1e-8);
verifyLessThanOrEqual(testCase,numel(r.T),p.maxSteps);
end

function testAdaptiveOutputBudgetBothSolvers(testCase)
for cd = [0.47 100]
    p = dragParams();
    p.Cd = cd;
    p.dt = 0.5;
    r = projectile_physics(p);
    % Impact at exactly the budget is allowed; one fewer sample must stop.
    p.maxSteps = numel(r.T);
    bounded = projectile_physics(p);
    verifyEqual(testCase,bounded.T,r.T);
    p.maxSteps = numel(r.T)-1;
    verifyError(testCase,@() projectile_physics(p),'projectile:StepLimit');
    p.maxSteps = 1;
    verifyError(testCase,@() projectile_physics(p),'projectile:StepLimit');
end
end

function p = pointParams()
p = struct('g',9.81,'dt',0.01,'model','point',...
    'theta',45,'h0',0,'v0',50);
end

function p = dragParams()
p = pointParams();
p.model = 'sphere';
p.Cd = 0.47;
p.rho = 1.225;
p.m = 1;
p.geometry = 'radius';
p.radius = 0.05;
p.area = 0.01;
end
