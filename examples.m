function examples()
%EXAMPLES Capture representative states of the running app for the README.

projectRoot = fileparts(mfilename('fullpath'));
outputDir = fullfile(projectRoot,'docs','images');
if ~isfolder(outputDir)
    mkdir(outputDir);
end

projectile_simulator();
drawnow;
fig = findall(groot,'Type','figure','Name','Projectile Motion Simulator');
if numel(fig) ~= 1
    error('projectile:ScreenshotSetup','Expected one simulator window.');
end
fig.Position = [60 60 1400 820];
cleanup = onCleanup(@() closeSimulator(fig));

buttons = findall(fig,'Type','uibutton');
runButton = findControl(buttons,@(h) contains(string(h.Text),'Run Simulation'));
speedSpinner = findall(fig,'Type','uispinner');
speedSpinner.Value = 20;

% Default point-mass run.
invokeCallback(runButton.ButtonPushedFcn,runButton);
pause(0.6);
drawnow;
exportapp(fig,fullfile(outputDir,'point-mass-run.png'));

% Add a contrasting drag run at a steeper angle.
checkboxes = findall(fig,'Type','uicheckbox');
compareToggle = findControl(checkboxes,@(h) contains(string(h.Tooltip),'Comparison mode'));
compareToggle.Value = true;

allControls = findall(fig);
angleField = findControl(allControls,@(h) ...
    isprop(h,'Value') && isnumeric(h.Value) && isequal(h.Value,45));
angleField.Value = 60;

dropdowns = findall(fig,'Type','uidropdown');
modelDropdown = findControl(dropdowns,@(h) any(strcmp(h.Items,'Sphere with Drag')));
modelDropdown.Value = 'Sphere with Drag';
invokeCallback(modelDropdown.ValueChangedFcn,modelDropdown);

invokeCallback(runButton.ButtonPushedFcn,runButton);
pause(0.6);
drawnow;
exportapp(fig,fullfile(outputDir,'comparison-run.png'));

% Show the numeric results for both runs.
tabs = findall(fig,'Type','uitab');
summaryTab = findControl(tabs,@(h) strcmp(h.Title,'Summary'));
tabGroup = summaryTab.Parent;
tabGroup.SelectedTab = summaryTab;
drawnow;
exportapp(fig,fullfile(outputDir,'summary-results.png'));

clear cleanup;
closeSimulator(fig);
end

function control = findControl(controls,predicate)
matches = false(size(controls));
for i = 1:numel(controls)
    matches(i) = predicate(controls(i));
end
control = controls(matches);
if numel(control) ~= 1
    error('projectile:ScreenshotSetup','Expected one matching UI control.');
end
end

function invokeCallback(callback,source)
if isa(callback,'function_handle')
    callback(source,[]);
elseif iscell(callback)
    callback{1}(source,[],callback{2:end});
else
    error('projectile:ScreenshotSetup','Unsupported callback type.');
end
end

function closeSimulator(fig)
timers = timerfindall;
if ~isempty(timers)
    stop(timers);
    delete(timers);
end
if isgraphics(fig)
    delete(fig);
end
end
