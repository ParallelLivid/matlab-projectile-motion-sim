function projectile_simulator()

%% ===== DEFAULT PARAMETERS =====
defaults = struct( ...
    'v0',50,'theta',45,'h0',0,'g',9.81,...
    'radius',0.05,'area',0.01,...
    'Cd',0.47,'rho',1.225,'m',1,...
    'dt',0.01,...
    'model','point',...
    'geometry','radius');

TIMER_PERIOD = 0.016;
TAIL_SECONDS = 0.75;
MAX_HISTORY  = 12;

%% ===== COLOUR PALETTE =====
C.bg      = [0.07 0.10 0.17];   % figure / outermost background
C.panel   = [0.09 0.13 0.22];   % panel & tab background
C.surface = [0.12 0.17 0.28];   % input fields, control surfaces
C.accent  = [0.38 0.70 1.00];   % light-blue accent  (text highlights)
C.accentB = [0.16 0.38 0.72];   % darker accent      (Run button)
C.text    = [0.88 0.92 0.98];   % primary text
C.textDim = [0.50 0.62 0.78];   % secondary / dimmed text
C.hdrBg   = [0.11 0.18 0.33];   % section-header background
C.hdrText = [0.48 0.74 1.00];   % section-header text
C.qBg     = [0.20 0.42 0.78];   % ? badge background
C.grid    = [0.18 0.26 0.42];   % axes grid lines
C.toolbox = [0.10 0.22 0.48];   % left-panel background blue

%% ===== FIGURE =====
fig = uifigure('Name','Projectile Motion Simulator',...
               'Position',[100 100 1240 700],...
               'Color', C.bg);

outerGrid = uigridlayout(fig,[1 2]);
outerGrid.ColumnWidth  = {286,'1x'};
outerGrid.ColumnSpacing = 0;
outerGrid.Padding       = [0 0 0 0];

%% ===== LEFT PANEL =====
leftPanel = uipanel(outerGrid,...
    'Title',           'Simulation Parameters',...
    'FontWeight',      'bold',...
    'FontSize',        11,...
    'ForegroundColor', C.accent,...
    'BackgroundColor', C.toolbox,...
    'BorderColor',     C.accentB);

% 3-column: label | field | ?
leftLayout = uigridlayout(leftPanel,[21 3]);
leftLayout.ColumnWidth   = {'1x', 88, 22};
leftLayout.RowHeight     = {23, 16, 23, 23, 23, 16, 23, ...
                             16, 23, 23, 23, 23, 23, 23, ...
                             16, 23, 16, 23, 10, 30, 28};
leftLayout.RowSpacing    = 2;
leftLayout.ColumnSpacing = 4;
leftLayout.Padding          = [8 6 8 6];
leftLayout.BackgroundColor  = C.toolbox;

%% ── Inner UI helpers ─────────────────────────────────────────────────────────

    function s = tip(desc, units, range, dflt)
        s = sprintf('%s\n\nUnits:    %s\nRange:    %s\nDefault:  %s', ...
            desc, units, range, dflt);
    end

    function q = makeQ(row, tipText)
        q = uilabel(leftLayout,'Text','?',...
            'FontSize',9,'FontWeight','bold',...
            'FontColor',          C.text,...
            'BackgroundColor',    C.qBg,...
            'HorizontalAlignment','center',...
            'VerticalAlignment',  'center',...
            'Tooltip', tipText);
        q.Layout.Row = row; q.Layout.Column = 3;
    end

    function h = makeSectionHdr(row, txt)
        h = uilabel(leftLayout,'Text',txt,...
            'FontSize',9,'FontWeight','bold',...
            'FontColor',          C.hdrText,...
            'BackgroundColor',    C.hdrBg,...
            'HorizontalAlignment','left',...
            'VerticalAlignment',  'center');
        h.Layout.Row = row; h.Layout.Column = [1 3];
    end

    function l = makeLabel(row, txt)
        l = uilabel(leftLayout,'Text',txt,...
            'FontColor',          C.text,...
            'HorizontalAlignment','right',...
            'VerticalAlignment',  'center',...
            'FontSize',11);
        l.Layout.Row = row; l.Layout.Column = 1;
    end

    function fld = makeField(row, fname, tipText, varargin)
        fld = uieditfield(leftLayout,'numeric',...
            'Value',          defaults.(fname),...
            'BackgroundColor',C.surface,...
            'FontColor',      C.text,...
            'Tooltip',        tipText,...
            varargin{:});
        fld.Layout.Row = row; fld.Layout.Column = 2;
    end

    function dd = makeDropdown(row, items, val, tipText)
        dd = uidropdown(leftLayout,...
            'Items',          items,...
            'Value',          val,...
            'BackgroundColor',C.surface,...
            'FontColor',      C.text,...
            'Tooltip',        tipText);
        dd.Layout.Row = row; dd.Layout.Column = 2;
    end

%% ── Row 1: Model ─────────────────────────────────────────────────────────────
tModel = 'Physics model used for the simulation.\n\nPoint Mass: no air resistance; follows an ideal parabola.\nSphere with Drag: adds aerodynamic drag force opposing velocity (F = ½CdρAv²).';
makeLabel(1,'Model');
modelSelect = makeDropdown(1,{'Point Mass','Sphere with Drag'},'Point Mass', tModel);
modelSelect.ValueChangedFcn = @updateModel;
makeQ(1, tModel);

%% ── Row 2: LAUNCH header ─────────────────────────────────────────────────────
makeSectionHdr(2,'  ▸  LAUNCH');

%% ── Row 3: v0 ────────────────────────────────────────────────────────────────
t = tip('Launch speed of the projectile at t = 0.','m/s','0 – 5000','50');
makeLabel(3,'v₀   Speed');
inputs.v0 = makeField(3,'v0',t,'Limits',[0 5000],...
    'LowerLimitInclusive','on','UpperLimitInclusive','on');
makeQ(3,t);

%% ── Row 4: theta ─────────────────────────────────────────────────────────────
t = tip('Launch angle measured above the horizontal. Clamped to valid ballistic range.','degrees','0 – 90','45');
makeLabel(4,'θ   Angle');
inputs.theta = makeField(4,'theta',t,...
    'Limits',[0 90],'LowerLimitInclusive','on','UpperLimitInclusive','on');
makeQ(4,t);

%% ── Row 5: h0 ────────────────────────────────────────────────────────────────
t = tip('Height of the launch point above the ground (y = 0 is the ground).','m','0 – 100000','0');
makeLabel(5,'h₀   Height');
inputs.h0 = makeField(5,'h0',t,'Limits',[0 100000],...
    'LowerLimitInclusive','on','UpperLimitInclusive','on');
makeQ(5,t);

%% ── Row 6: ENVIRONMENT header ────────────────────────────────────────────────
makeSectionHdr(6,'  ▸  ENVIRONMENT');

%% ── Row 7: g ─────────────────────────────────────────────────────────────────
t = tip(sprintf('Gravitational acceleration.\n  Earth  ≈ 9.81 m/s²\n  Moon   ≈ 1.62 m/s²\n  Mars   ≈ 3.72 m/s²'),...
    'm/s²','0.01 – 100','9.81');
makeLabel(7,'g   Gravity');
inputs.g = makeField(7,'g',t,'Limits',[0.01 100],...
    'LowerLimitInclusive','on','UpperLimitInclusive','on');
makeQ(7,t);

%% ── Row 8-14: DRAG section — handles captured for show/hide ─────────────────
dragRowHeights = {16, 23, 23, 23, 23, 23, 23};   % restored when drag is visible

dw_hdr  = makeSectionHdr(8,'  ▸  DRAG  (Sphere model only)');

tGeom   = sprintf('How the projectile cross-section is specified.\n  Radius → A = π r²\n  Area   → A entered directly');
dw_lGeom = makeLabel(9,'Geometry');
geomSelect = makeDropdown(9,{'Radius','Area'},'Radius', tGeom);
geomSelect.ValueChangedFcn = @updateGeometry;
dw_qGeom = makeQ(9, tGeom);

t = tip(sprintf('Sphere radius. Cross-sectional area computed as A = π r².\nOnly active when Geometry = Radius.'),'m','> 0','0.05');
dw_lRad  = makeLabel(10,'r   Radius');
inputs.radius = makeField(10,'radius',t,'Limits',[0.0001 100],...
    'LowerLimitInclusive','on','UpperLimitInclusive','on');
dw_qRad  = makeQ(10,t);

t = tip(sprintf('Frontal cross-sectional area used directly in the drag equation.\nOnly active when Geometry = Area.'),'m²','> 0','0.01');
dw_lArea = makeLabel(11,'A   Area');
inputs.area = makeField(11,'area',t,'Limits',[1e-8 10000],...
    'LowerLimitInclusive','on','UpperLimitInclusive','on');
dw_qArea = makeQ(11,t);

t = tip(sprintf('Aerodynamic drag coefficient.\n  Smooth sphere    ≈ 0.47\n  Rough sphere     ≈ 0.20 – 0.50\n  Streamlined body ≈ 0.04'),'dimensionless','0 – 2 (typical)','0.47');
dw_lCd   = makeLabel(12,'Cd   Drag coeff.');
inputs.Cd = makeField(12,'Cd',t,'Limits',[0 10],...
    'LowerLimitInclusive','on','UpperLimitInclusive','on');
dw_qCd   = makeQ(12,t);

t = tip(sprintf('Density of the surrounding fluid.\n  Sea-level air ≈ 1.225 kg/m³\n  Water         ≈ 1000  kg/m³\n  Vacuum        = 0    (disables drag)'),'kg/m³','≥ 0','1.225');
dw_lRho  = makeLabel(13,'ρ   Air density');
inputs.rho = makeField(13,'rho',t,'Limits',[0 2000],...
    'LowerLimitInclusive','on','UpperLimitInclusive','on');
dw_qRho  = makeQ(13,t);

t = tip('Mass of the projectile. Heavier objects decelerate less for the same drag force (a = F/m).','kg','> 0','1');
dw_lM    = makeLabel(14,'m   Mass');
inputs.m = makeField(14,'m',t,'Limits',[0.0001 1e6],...
    'LowerLimitInclusive','on','UpperLimitInclusive','on');
dw_qM    = makeQ(14,t);

% All widgets in the drag section (rows 8-14) — for Visible toggling
dragWidgets = {dw_hdr, dw_lGeom, geomSelect, dw_qGeom, ...
               dw_lRad, inputs.radius, dw_qRad, ...
               dw_lArea, inputs.area, dw_qArea, ...
               dw_lCd, inputs.Cd, dw_qCd, ...
               dw_lRho, inputs.rho, dw_qRho, ...
               dw_lM, inputs.m, dw_qM};

%% ── Row 15: SIMULATION header ────────────────────────────────────────────────
makeSectionHdr(15,'  ▸  SIMULATION');

%% ── Row 16: dt ───────────────────────────────────────────────────────────────
t = tip(sprintf('Maximum solver step / point-mass sample interval.\n  Smaller → denser output, slower.\n  Recommended: 0.001 – 0.05 s'),...
    's','0.0005 – 0.5','0.01');
makeLabel(16,'dt   Time step');
inputs.dt = makeField(16,'dt',t,...
    'Limits',[0.0005 0.5],'LowerLimitInclusive','on','UpperLimitInclusive','on');
makeQ(16,t);

%% ── Row 17: OPTIONS header ───────────────────────────────────────────────────
makeSectionHdr(17,'  ▸  OPTIONS');

%% ── Row 18: Comparison mode ──────────────────────────────────────────────────
tComp = sprintf('Comparison mode.\n\nWhen ON:  each Run overlays a new trace, building up a comparison set.\nWhen OFF: each Run replaces the previous result.\n\nUseful for comparing angle, speed, or drag settings side-by-side.');
makeLabel(18,'Comparison mode');
compareToggle = uicheckbox(leftLayout,'Value',false,'Text','',...
    'FontColor', C.text,...
    'Tooltip', tComp);
compareToggle.Layout.Row = 18; compareToggle.Layout.Column = 2;
makeQ(18, tComp);

%% ── Row 19: spacer ───────────────────────────────────────────────────────────
% (empty row for breathing room above buttons)

%% ── Row 20: Run button ───────────────────────────────────────────────────────
runBtn = uibutton(leftLayout,'Text','▶   Run Simulation',...
    'ButtonPushedFcn',@runSim,...
    'BackgroundColor',C.accentB,...
    'FontColor',[1 1 1],'FontWeight','bold','FontSize',12);
runBtn.Layout.Row = 20; runBtn.Layout.Column = [1 3];

%% ── Row 21: Reset button ─────────────────────────────────────────────────────
resetBtn = uibutton(leftLayout,'Text','↺   Reset Defaults',...
    'ButtonPushedFcn',@resetDefaults,...
    'BackgroundColor',C.hdrBg,...
    'FontColor',C.textDim);
resetBtn.Layout.Row = 21; resetBtn.Layout.Column = [1 3];

%% ===== RIGHT PANEL =====
tabs = uitabgroup(outerGrid);

tabAnim    = uitab(tabs,'Title','Animation',   'BackgroundColor',C.panel);
tabPos     = uitab(tabs,'Title','Position',    'BackgroundColor',C.panel);
tabVel     = uitab(tabs,'Title','Velocity',    'BackgroundColor',C.panel);
tabSummary = uitab(tabs,'Title','Summary',     'BackgroundColor',C.panel);

%% ---- Helper: apply dark theme to any uiaxes ────────────────────────────────
    function styleAxes(ax, ttl, xl, yl)
        ax.Color            = [0.00 0.00 0.00];   % black plot area
        ax.XColor           = [1.00 1.00 1.00];   % white ticks & labels
        ax.YColor           = [1.00 1.00 1.00];
        ax.GridColor        = [0.35 0.35 0.35];   % mid-grey grid
        ax.MinorGridColor   = [0.25 0.25 0.25];
        ax.GridAlpha        = 0.6;
        ax.MinorGridAlpha   = 0.4;
        ax.XGrid            = 'on';
        ax.YGrid            = 'on';
        ax.Box              = 'on';
        ax.Title.String     = ttl;
        ax.Title.Color      = C.accent;           % light-blue title
        ax.Title.FontWeight = 'bold';
        ax.XLabel.String    = xl;
        ax.XLabel.Color     = [0.80 0.80 0.80];
        ax.YLabel.String    = yl;
        ax.YLabel.Color     = [0.80 0.80 0.80];
        ax.FontSize         = 10;
    end

%% ---- Animation tab ─────────────────────────────────────────────────────────
animOuter = uigridlayout(tabAnim,[4 1]);
animOuter.RowHeight  = {'1x', 36, 38, 22};
animOuter.Padding    = [6 6 6 4];
animOuter.RowSpacing = 4;
animOuter.BackgroundColor = C.panel;

axAnim = uiaxes(animOuter);
axAnim.Layout.Row = 1;
styleAxes(axAnim,'Trajectory','X (m)','Y (m)');

% Controls bar (row 2)
ctrlGrid = uigridlayout(animOuter,[1 11]);
ctrlGrid.Layout.Row    = 2;
ctrlGrid.ColumnWidth   = {90, 80, 52, 120, 46, 22, 74, 22, 58, '1x', 100};
ctrlGrid.Padding       = [0 2 0 2];
ctrlGrid.ColumnSpacing = 6;
ctrlGrid.BackgroundColor = C.panel;

replayBtn = uibutton(ctrlGrid,'Text','↺  Replay',...
    'ButtonPushedFcn',@replayAnim,'Enable','off',...
    'BackgroundColor',C.hdrBg,'FontColor',C.textDim);
stopBtn = uibutton(ctrlGrid,'Text','■  Stop',...
    'ButtonPushedFcn',@stopAnim,'Enable','off',...
    'BackgroundColor',C.hdrBg,'FontColor',C.textDim);

uilabel(ctrlGrid,'Text','Speed','HorizontalAlignment','right',...
    'FontColor',C.textDim);
speedSpinner = uispinner(ctrlGrid,...
    'Value',1,'Limits',[0.1 20],'Step',0.25,...
    'ValueDisplayFormat','%.2fx','RoundFractionalValues',false,...
    'BackgroundColor',C.surface,'FontColor',C.text);

uilabel(ctrlGrid,'Text','Loop','HorizontalAlignment','right',...
    'FontColor',C.textDim);
loopToggle = uicheckbox(ctrlGrid,'Value',false,'Text','',...
    'FontColor',C.text);

uilabel(ctrlGrid,'Text','Equal axes','HorizontalAlignment','right',...
    'FontColor',C.textDim);
equalAxesToggle = uicheckbox(ctrlGrid,'Value',true,'Text','',...
    'FontColor',C.text,...
    'ValueChangedFcn',@(~,~) applyAnimScaling());

uilabel(ctrlGrid,'Text','Progress','HorizontalAlignment','right',...
    'FontColor',C.textDim);
progressLabel = uilabel(ctrlGrid,'Text','–',...
    'HorizontalAlignment','left','FontColor',C.accent);

fsBtn = uibutton(ctrlGrid,'Text','⛶  Fullscreen',...
    'ButtonPushedFcn',@toggleFullscreen,...
    'BackgroundColor',C.accentB,'FontColor',[1 1 1]);

% Scrubber row (row 3)
scrubGrid = uigridlayout(animOuter,[1 3]);
scrubGrid.Layout.Row     = 3;
scrubGrid.ColumnWidth    = {44,'1x',60};
scrubGrid.Padding        = [4 2 4 0];
scrubGrid.ColumnSpacing  = 8;
scrubGrid.BackgroundColor = C.panel;

uilabel(scrubGrid,'Text','t (s)','HorizontalAlignment','right',...
    'FontWeight','bold','FontColor',C.accent);

scrubSlider = uislider(scrubGrid,...
    'Limits',[0 1],'Value',0,'Enable','off',...
    'ValueChangedFcn', @(~,e) onScrub(e.Value),...
    'ValueChangingFcn',@(~,e) onScrub(e.Value),...
    'FontColor',C.textDim);

scrubTimeLabel = uilabel(scrubGrid,'Text','–',...
    'HorizontalAlignment','left','FontColor',C.accent);

% Status bar (row 4)
statusLabel = uilabel(animOuter,...
    'Text','Run a simulation to begin.',...
    'HorizontalAlignment','center','FontColor',C.textDim,...
    'BackgroundColor',C.hdrBg);
statusLabel.Layout.Row = 4;

%% ---- Position tab ──────────────────────────────────────────────────────────
posOuter = uigridlayout(tabPos,[1 1]);
posOuter.Padding = [6 6 6 6];
posOuter.BackgroundColor = C.panel;
axPos = uiaxes(posOuter);
styleAxes(axPos,'Position vs Time','Time (s)','Position (m)');

%% ---- Velocity tab ──────────────────────────────────────────────────────────
velOuter = uigridlayout(tabVel,[1 1]);
velOuter.Padding = [6 6 6 6];
velOuter.BackgroundColor = C.panel;
axVel = uiaxes(velOuter);
styleAxes(axVel,'Velocity vs Time','Time (s)','Velocity (m/s)');

%% ---- Summary tab ───────────────────────────────────────────────────────────
summaryOuter = uigridlayout(tabSummary,[1 1]);
summaryOuter.Padding = [8 8 8 8];
summaryOuter.BackgroundColor = C.panel;
summaryTable = uitable(summaryOuter,...
    'ColumnName',{'Run','Model','Parameters','Flight Time (s)','Range (m)',...
                  'Max Height (m)','Time to Apex (s)',...
                  'Launch Speed (m/s)','Max Speed (m/s)',...
                  'Impact Speed (m/s)','Impact Angle (°, down < 0)'},...
    'RowName',{},'Data',{},...
    'BackgroundColor',[C.surface; C.hdrBg],...
    'ForegroundColor',C.text,...
    'ColumnWidth',{38,130,260,118,90,118,118,140,120,130,115});

%% ===== SHARED STATE =====
fields    = fieldnames(defaults);
history   = {};
colors    = [0.38 0.70 1.00;   % light blue
             1.00 0.60 0.20;   % amber
             0.35 0.90 0.55;   % green
             1.00 0.40 0.45;   % rose
             0.75 0.45 1.00;   % violet
             0.25 0.85 0.95;   % cyan
             1.00 0.85 0.25;   % yellow
             1.00 0.55 0.80];  % pink
animTimer = [];
animPoint = [];
tailLine  = [];
simTime   = 0;
lastTick  = [];
animCompleted = false;
stopRequested = false;

%% ===== MODEL / GEOMETRY TOGGLES =====
    function updateModel(~,~)
        isDrag = strcmp(modelSelect.Value,'Sphere with Drag');
        % Show/hide entire drag section by toggling visibility and row heights
        vis = pickStr(isDrag,'on','off');
        for wi = 1:numel(dragWidgets)
            dragWidgets{wi}.Visible = vis;
        end
        if isDrag
            leftLayout.RowHeight(8:14) = dragRowHeights;
        else
            leftLayout.RowHeight(8:14) = {0,0,0,0,0,0,0};
        end
        if isDrag, updateGeometry(); end
    end

    function updateGeometry(~,~)
        byRadius = strcmp(geomSelect.Value,'Radius');
        inputs.radius.Enable = pickStr(byRadius,'on','off');
        inputs.area.Enable   = pickStr(byRadius,'off','on');
    end

%% ===== RUN SIMULATION =====
    function runSim(~,~)
        stopAnim();

        if compareToggle.Value && numel(history) >= MAX_HISTORY
            uialert(fig,sprintf('Comparison mode is limited to %d runs. Reset to start a new set.',...
                MAX_HISTORY),'Comparison Limit','Icon','warning');
            return;
        end

        params = defaults;
        for i = 1:length(fields)
            fname = fields{i};
            if strcmp(fname,'model') || strcmp(fname,'geometry'), continue; end
            params.(fname) = inputs.(fname).Value;
        end
        params.model    = pickStr(strcmp(modelSelect.Value,'Point Mass'),'point','sphere');
        params.geometry = pickStr(strcmp(geomSelect.Value,'Radius'),'radius','area');

        runBtn.Enable = 'off';
        statusLabel.Text = 'Solving trajectory…';
        drawnow;
        try
            results = projectile_physics(params);
        catch ME
            runBtn.Enable = 'on';
            statusLabel.Text = 'Simulation failed. Adjust the parameters and try again.';
            uialert(fig,ME.message,'Simulation Error','Icon','error');
            return;
        end
        runBtn.Enable = 'on';
        results.modelLabel = modelSelect.Value;
        results.parametersLabel = formatParameters(params);

        if compareToggle.Value
            history{end+1} = results;
        else
            history = {results};
        end

        plotStaticGraphs();
        startAnimation();
        updateSummaryTable();
    end

%% ===== AXIS SCALING =====
    function applyAnimScaling()
        if isempty(history), return; end
        allX = []; allY = [];
        for i = 1:length(history)
            allX = [allX, history{i}.X]; %#ok<AGROW>
            allY = [allY, history{i}.Y]; %#ok<AGROW>
        end
        xlim(axAnim,[0, safeMax(allX)*1.1]);
        ylim(axAnim,[0, safeMax(allY)*1.1]);
        if equalAxesToggle.Value
            axis(axAnim,'equal');
            axAnim.XLim(1) = 0;
            axAnim.YLim(1) = 0;
        else
            axis(axAnim,'normal');
        end
    end

%% ===== STATIC GRAPHS =====
    function plotStaticGraphs()
        cla(axAnim); cla(axPos); cla(axVel);
        hold(axAnim,'on'); hold(axPos,'on'); hold(axVel,'on');

        for i = 1:length(history)
            r = history{i};
            c = colors(mod(i-1,size(colors,1))+1,:);
            runName = sprintf('Run %d: %s',i,r.parametersLabel);
            plot(axAnim,r.X,r.Y,'--','Color',c,'LineWidth',1.4,...
                'DisplayName',runName);
            plot(axPos,r.T,r.X,'--','Color',c,'LineWidth',1.4,...
                'DisplayName',sprintf('Run %d — x',i));
            plot(axPos,r.T,r.Y,'-','Color',c,'LineWidth',1.4,...
                'DisplayName',sprintf('Run %d — y',i));
            plot(axVel,r.T,r.VX,'--','Color',c,'LineWidth',1.4,...
                'DisplayName',sprintf('Run %d — vx',i));
            plot(axVel,r.T,r.VY,'-','Color',c,'LineWidth',1.4,...
                'DisplayName',sprintf('Run %d — vy',i));
        end

        ground = yline(axAnim,0,'-','Ground','Color',C.textDim,'LineWidth',1);
        ground.HandleVisibility = 'off';
        lg0 = legend(axAnim,'show'); lg0.TextColor = C.text; lg0.Color = C.hdrBg;
        lg1 = legend(axPos,'show');  lg1.TextColor = C.text; lg1.Color = C.hdrBg;
        lg2 = legend(axVel,'show');  lg2.TextColor = C.text; lg2.Color = C.hdrBg;
        applyAnimScaling();
    end

%% ===== SCRUBBER =====
    function onScrub(t_req)
        if isempty(history), return; end
        stopAnim();
        scrubToFrame(t_req);
    end

    function scrubToFrame(t_req)
        if isempty(history)||isempty(animPoint)||~isvalid(animPoint), return; end
        latest = history{end};
        N = length(latest.T);
        [~,k] = min(abs(latest.T - t_req));

        animPoint.XData = latest.X(k);
        animPoint.YData = latest.Y(k);
        tail0 = find(latest.T >= latest.T(k)-TAIL_SECONDS,1,'first');
        tailLine.XData = latest.X(tail0:k);
        tailLine.YData = latest.Y(tail0:k);

        scrubTimeLabel.Text = sprintf('%.2f s', latest.T(k));
        progressLabel.Text  = sprintf('%d%%', frameProgress(k,N));
        statusLabel.Text    = sprintf(...
            't = %.2f s  |  x = %.2f m  |  y = %.2f m  |  vx = %.2f m/s  |  vy = %.2f m/s',...
            latest.T(k),latest.X(k),latest.Y(k),latest.VX(k),latest.VY(k));
        drawnow limitrate;
    end

%% ===== ANIMATION ENGINE =====
    function startAnimation(~,~)
        if isempty(history), return; end
        stopAnim();

        latest  = history{end};
        N       = length(latest.X);
        T_end   = latest.T(end);
        simTime = 0;
        animCompleted = false;
        stopRequested = false;

        sliderEnd = max(T_end,eps);
        scrubSlider.Limits = [0, sliderEnd];
        scrubSlider.Value  = 0;
        nTicks = min(11, max(2, round(T_end)+1));
        ticks  = linspace(0, sliderEnd, nTicks);
        scrubSlider.MajorTicks      = ticks;
        scrubSlider.MajorTickLabels = arrayfun(@(t) sprintf('%.1f',t),ticks,'UniformOutput',false);
        scrubSlider.MinorTicks      = [];
        scrubSlider.Enable          = pickStr(N > 1,'on','off');
        scrubTimeLabel.Text         = '0.00 s';

        applyAnimScaling();
        k = 1;

        tailLine = plot(axAnim, latest.X(1), latest.Y(1),...
            '-','Color',[0.38 0.70 1.00 0.30],'LineWidth',3,...
            'HandleVisibility','off');
        animPoint = plot(axAnim, latest.X(1), latest.Y(1),...
            'o','MarkerSize',11,...
            'MarkerFaceColor',[0.38 0.70 1.00],...
            'MarkerEdgeColor',[1 1 1],...
            'LineWidth',1.2,'HandleVisibility','off');

        if N == 1 || T_end == 0
            progressLabel.Text = '100%';
            statusLabel.Text = 'Done — projectile is already at ground level.';
            setAnimButtons(true);
            return;
        end

        setAnimButtons(false);
        lastTick = tic;

        animTimer = timer('ExecutionMode','fixedRate','Period',TIMER_PERIOD,...
            'BusyMode','drop','TimerFcn',@stepAnim,'StopFcn',@onAnimStop);
        start(animTimer);

        function stepAnim(~,~)
            if ~isvalid(fig)||~isvalid(axAnim)||~isvalid(animPoint)||~isvalid(tailLine)
                stopAnim(); return;
            end
            elapsed = toc(lastTick);
            lastTick = tic;
            simTime = min(T_end,simTime + elapsed*speedSpinner.Value);
            k = find(latest.T <= simTime,1,'last');
            if isempty(k), k = 1; end
            if simTime >= T_end, k = N; end

            animPoint.XData = latest.X(k);
            animPoint.YData = latest.Y(k);
            tail0 = find(latest.T >= latest.T(k)-TAIL_SECONDS,1,'first');
            tailLine.XData = latest.X(tail0:k);
            tailLine.YData = latest.Y(tail0:k);

            scrubSlider.Value   = latest.T(k);
            scrubTimeLabel.Text = sprintf('%.2f s', latest.T(k));
            progressLabel.Text  = sprintf('%d%%', frameProgress(k,N));
            statusLabel.Text    = sprintf(...
                't = %.2f s  |  x = %.2f m  |  y = %.2f m  |  vx = %.2f m/s  |  vy = %.2f m/s',...
                latest.T(k),latest.X(k),latest.Y(k),latest.VX(k),latest.VY(k));
            drawnow limitrate;

            if k >= N
                animCompleted = true;
                stopRequested = false;
                stop(animTimer);
            end
        end

        function onAnimStop(~,~)
            if ~isvalid(fig), return; end
            if loopToggle.Value && animCompleted && ~stopRequested
                simTime = 0;
                k = 1;
                animCompleted = false;
                animPoint.XData = latest.X(1);
                animPoint.YData = latest.Y(1);
                tailLine.XData = latest.X(1);
                tailLine.YData = latest.Y(1);
                scrubSlider.Value = 0;
                scrubTimeLabel.Text = '0.00 s';
                progressLabel.Text = '0%';
                lastTick = tic;
                start(animTimer);
            elseif stopRequested
                setAnimButtons(true);
                if isvalid(statusLabel)
                    statusLabel.Text = sprintf('Stopped at t = %.2f s.',latest.T(k));
                end
            else
                setAnimButtons(true);
                if isvalid(statusLabel)
                    statusLabel.Text = sprintf(...
                        'Done — flight time %.2f s  |  range %.2f m',...
                        latest.T(end), latest.X(end));
                end
                if isvalid(progressLabel), progressLabel.Text = '100%'; end
            end
        end
    end

    function replayAnim(~,~)
        if isempty(history), return; end
        plotStaticGraphs();
        startAnimation();
    end

    function stopAnim(varargin)
        if ~isempty(animTimer) && isvalid(animTimer)
            stopRequested = true;
            stop(animTimer); delete(animTimer);
        end
        animTimer = [];
        if isvalid(fig), setAnimButtons(true); end
    end

    function setAnimButtons(idle)
        if ~isvalid(fig), return; end
        hasHistory = ~isempty(history);
        replayBtn.Enable = pickStr(idle && hasHistory,'on','off');
        stopBtn.Enable   = pickStr(~idle,'on','off');
        replayBtn.FontColor = pickColor(idle && hasHistory,C.text,C.textDim);
        stopBtn.FontColor   = pickColor(~idle,C.text,C.textDim);
    end

%% ===== SUMMARY TAB =====
    function s = computeFlightSummary(r)
        v = sqrt(r.VX.^2 + r.VY.^2);
        s.hmax           = r.maxHeight;
        s.t_apex         = r.apexTime;
        s.vmax           = max(v);
        s.v_launch       = v(1);
        s.v_impact       = r.impactSpeed;
        s.theta_impact   = r.impactAngle;
        s.t_flight       = r.impactTime;
        s.range          = r.range;
        s.model          = r.modelLabel;
        s.parameters     = r.parametersLabel;
    end

    function updateSummaryTable()
        data = cell(length(history),11);
        for i = 1:length(history)
            s = computeFlightSummary(history{i});
            data(i,:) = {i, s.model, s.parameters,...
                sprintf('%.3f', s.t_flight),...
                sprintf('%.2f', s.range),...
                sprintf('%.2f', s.hmax),...
                sprintf('%.3f', s.t_apex),...
                sprintf('%.2f', s.v_launch),...
                sprintf('%.2f', s.vmax),...
                sprintf('%.2f', s.v_impact),...
                sprintf('%.1f', s.theta_impact)};
        end
        summaryTable.Data = data;
    end

%% ===== RESET =====
    function resetDefaults(~,~)
        stopAnim();
        for i = 1:length(fields)
            fname = fields{i};
            if strcmp(fname,'model')||strcmp(fname,'geometry'), continue; end
            inputs.(fname).Value = defaults.(fname);
        end
        modelSelect.Value     = 'Point Mass';
        geomSelect.Value      = 'Radius';
        compareToggle.Value   = false;
        equalAxesToggle.Value = true;
        loopToggle.Value      = false;
        speedSpinner.Value    = 1;
        history = {};
        cla(axAnim); cla(axPos); cla(axVel);
        summaryTable.Data   = {};
        statusLabel.Text    = 'Run a simulation to begin.';
        progressLabel.Text  = '–';
        scrubSlider.Limits  = [0 1];
        scrubSlider.Value   = 0;
        scrubSlider.Enable  = 'off';
        scrubTimeLabel.Text = '–';
        setAnimButtons(true);
        updateModel();
    end

%% ===== FULLSCREEN =====
    function toggleFullscreen(~,~)
        if strcmp(fig.WindowState,'fullscreen')
            fig.WindowState = 'normal';
            fsBtn.Text      = '⛶  Fullscreen';
        else
            fig.WindowState = 'fullscreen';
            fsBtn.Text      = '⊡  Restore';
        end
    end

%% ===== HELPERS =====
    function percent = frameProgress(frame,count)
        percent = round(100*(frame-1)/max(1,count-1));
    end

    function label = formatParameters(p)
        label = sprintf('v₀=%g m/s, θ=%g°, h₀=%g m, dt=%g s',...
            p.v0,p.theta,p.h0,p.dt);
        if strcmp(p.model,'sphere')
            if strcmp(p.geometry,'radius')
                geom = sprintf('r=%g m',p.radius);
            else
                geom = sprintf('A=%g m²',p.area);
            end
            label = sprintf('%s, %s, Cd=%g, ρ=%g kg/m³, m=%g kg',...
                label,geom,p.Cd,p.rho,p.m);
        end
    end

    function v = safeMax(arr)
        v = max(arr);
        if isempty(v)||~isfinite(v)||v<=0, v=1; end
    end

    function s = pickStr(cond,a,b)
        if cond, s=a; else, s=b; end
    end

    function c = pickColor(cond,a,b)
        if cond, c=a; else, c=b; end
    end

%% ===== INIT =====
updateModel();

fig.CloseRequestFcn = @(~,~) onClose();
    function onClose()
        stopAnim();
        delete(fig);
    end

end
