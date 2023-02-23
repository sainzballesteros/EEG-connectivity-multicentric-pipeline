% heplab - Main GUI
%
% Copyright (C) 2019 Pandelis Perakakis, Granada University, peraka@ugr.es
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <https://www.gnu.org/licenses/>.

% check for HEP variable and load .mat file with ECG and srate vars
if ~exist('HEP','var')
    heplab_load_ECG
end

if ~exist('HEP','var')
    return
end

% close heplab window. There can be only one!
if exist ('hepgui','var') && isfield(hepgui,'main')
    if ishandle(hepgui.main)
        close (hepgui.main);
    end
end

% initiate HEP vars
HEP.ecg_handle = -1;
HEP.ecg = HEP.ecg(:);
HEP.ecg_dur_sec=length(HEP.ecg)/HEP.srate;
if HEP.ecg_dur_sec-HEP.winsec > 0
    HEP.slider_max = HEP.ecg_dur_sec-HEP.winsec;
else
    HEP.winsec = HEP.ecg_dur_sec;
    HEP.slider_max = 0;
end

% main window
hepgui.main = figure('Name','HEPLAB',...
    'resize','on',...
    'units','characters',...
    'Position',[181,53.73,178.714,50.8],...
    'NumberTitle', 'off',...
    'MenuBar','none',...
    'NumberTitle','off'...
    );

% plot ECG
HEP.ecg_handle = heplab_ecgplot(HEP.ecg,HEP.srate,HEP.qrs,...
    HEP.sec_ini,HEP.ecg_handle,HEP.winsec);

movegui(hepgui.main,'center')

%%%% SLIDER %%%%
% slider frame
hepgui.slider_fr = uipanel('parent',hepgui.main,...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'Position',[0.0663469224620304 0.089238845144357 0.842525979216627 0.122047244094488],...
    'Visible','on');

% min slider text
hepgui.min_slider = uicontrol('parent',hepgui.slider_fr,...
    'units','normalized',...
    'fontunits','pixels',...
    'String','Min = 0s',...
    'Style','text',...
    'Position',[0.0560928433268859 0.592592592592593 0.0502901353965184 0.209876543209877],...
    'Visible','on');

% max slider text
hepgui.max_slider=uicontrol('Style','text',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...'
    'Position',[0.868471953578337 0.617283950617284 0.074468085106383 0.160493827160494],...
    'String',['Max=',num2str(HEP.ecg_dur_sec), 's'],...
    'HorizontalAlignment', 'left',...
    'parent',hepgui.slider_fr);

% the slider itself!
hepgui.slider_arrow=uicontrol('Style','slider',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'Position',[0.114119922630561 0.604938271604938 0.741779497098646 0.185185185185185],...
    'Min',0,'Max',HEP.slider_max,...
    'Visible','on',...
    'parent',hepgui.slider_fr,...
    'CallBack', [...
    'HEP.sec_ini=round(1000*get(hepgui.slider_arrow,''Value''))/1000;',...
    'HEP.ecg_handle=heplab_ecgplot(HEP.ecg,HEP.srate,HEP.qrs,',...
    'HEP.sec_ini,HEP.ecg_handle,HEP.winsec);',...
    'set(hepgui.win_label, ''String'',num2str(HEP.sec_ini));']);

%%%% CURSOR POSITION %%%%
% cursor position text
hepgui.win_txt=uicontrol('Style','text',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'Position',[0.0599613152804642 0.172839506172839 0.0502901353965184 0.160493827160494],...
    'String','Location',...
    'Visible','on',...
    'parent',hepgui.slider_fr);

% cursor position window
hepgui.win_label=uicontrol('Style','edit',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'Position',[0.110251450676983 0.123456790123457 0.0676982591876209 0.271604938271605],...
    'String',num2str(HEP.sec_ini),...
    'Visible','on',...
    'parent',hepgui.slider_fr,...
    'CallBack',[...
    'A=str2num(get(hepgui.win_label,''String''));',...
    'if length(A)==1,',...
    'if A(1) <= get(hepgui.slider_arrow,''Max'') & A(1)>=0,',...
    'set(hepgui.slider_arrow,''Value'',A(1));',...
    'elseif A(1)<=get(hepgui.slider_arrow,''Max'')+HEP.winsec & A(1)>=0,',...
    'set(hepgui.slider_arrow,''Value'',get(hepgui.slider_arrow,''Max''));',...
    'end,',...
    'HEP.sec_ini=round(1000*get(hepgui.slider_arrow,''Value''))/1000;',...
    'HEP.ecg_handle=heplab_ecgplot(HEP.ecg,HEP.srate,HEP.qrs,',...
    'HEP.sec_ini,HEP.ecg_handle,HEP.winsec);',...
    'end,',...
    'set(hepgui.win_label, ''String'',num2str(HEP.sec_ini));']);

%%%% SCALEBOX %%%%
% scalebox text
hepgui.scalebox_txt=uicontrol('Style','text',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'Position',[0.448742746615087 0.172839506172839 0.0502901353965184 0.160493827160494],...
    'String','Scale:',...
    'Visible','on',...
    'parent',hepgui.slider_fr,...
    'units','normalized');

% scalebox
hepgui.scalebox=uicontrol('Style','edit',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'Position',[0.497098646034816 0.123456790123457 0.0676982591876208 0.271604938271605],...
    'String','1',...
    'Visible','on',...
    'parent',hepgui.slider_fr,...
    'CallBack',[...
    'A=str2num(get(hepgui.scalebox,''String''));',...
    'if length(A)==1,',...
    'HEP.ecg = HEP.ecg*A;',...
    'HEP.ecg_handle=heplab_ecgplot(HEP.ecg,HEP.srate,HEP.qrs,',...
    'HEP.sec_ini,HEP.ecg_handle,HEP.winsec);',...
    'clear A;',...
    'end,',...
    ]);

%%%% FILTER %%%%
% low cf text
hepgui.filt_low_txt=uicontrol('Style','text',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'Position',[0.706963249516441 0.172839506172839 0.0502901353965184 0.160493827160494],...
    'String','Low cf:',...
    'Visible','on',...
    'parent',hepgui.slider_fr);

% high cf text
hepgui.filt_high_txt=uicontrol('Style','text',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'Position',[0.823017408123791 0.172839506172839 0.0502901353965184 0.160493827160494],...
    'String','High cf:',...
    'Visible','on',...
    'parent',hepgui.slider_fr);

% low cf value
hepgui.filt_low_val=uicontrol('Style','edit',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'Position',[0.760154738878143 0.123456790123457 0.0493230174081238 0.271604938271605],...
    'String','0.5',...
    'Visible','on',...
    'parent',hepgui.slider_fr);

% high cf value
hepgui.filt_high_val=uicontrol('Style','edit',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'Position',[0.874274661508704 0.123456790123457 0.0493230174081238 0.271604938271605],...
    'String','50',...
    'Visible','on',...
    'parent',hepgui.slider_fr);

% filter button
hepgui.filt_button=uicontrol('Style','pushbutton',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'Position',[0.63 0.1 0.0676982591876208 0.3],...
    'String','Filter',...
    'Visible','on',...
    'parent',hepgui.slider_fr,...
    'CallBack',[...
    'lcf = str2num(get(hepgui.filt_low_val,''String''));',...
    'hcf = str2num(get(hepgui.filt_high_val,''String''));',...
    'HEP.ecg = heplab_ecg_filt(HEP.ecg,HEP.srate,lcf,hcf);',...
    'HEP.ecg_handle=heplab_ecgplot(HEP.ecg,HEP.srate,HEP.qrs,',...
    'HEP.sec_ini,HEP.ecg_handle,HEP.winsec);',...
    'clear A lcf hcf;',...
    ]);

%%%% WIN SIZE %%%%
% win size text
hepgui.winsize_txt=uicontrol('Style','text',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'Position',[0.22 0.148148148148148 0.07 0.209876543209877],...
    'String','Win size:',...
    'Visible','on',...
    'parent',hepgui.slider_fr);

% left arrow
hepgui.lft_arrow=uicontrol('Style','pushbutton',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'String','<',...
    'Position',[0.290135396518375 0.123456790123457 0.0203094777562863 0.259259259259259],...
    'Visible','on',...
    'parent',hepgui.slider_fr,...
    'Callback',[...
    'if HEP.sec_ini-HEP.winsec >= 0,',...
    'HEP.sec_ini=HEP.sec_ini-HEP.winsec;',...
    'else,',...
    'HEP.sec_ini=0;',...
    'end,',...
    'set(hepgui.slider_arrow,''Value'',HEP.sec_ini);',...
    'HEP.ecg_handle=heplab_ecgplot(HEP.ecg,HEP.srate,HEP.qrs,HEP.sec_ini,',...
    'HEP.ecg_handle,HEP.winsec);',...
    'set(hepgui.win_label, ''String'',num2str(HEP.sec_ini));']);

% edit box
hepgui.winsize_label=uicontrol('Style','edit',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'Position',[0.318181818181818 0.123456790123457 0.0676982591876209 0.271604938271605],...
    'Value', HEP.winsec,...
    'String',num2str(HEP.winsec),...
    'Visible','on',...
    'parent',hepgui.slider_fr,...
    'Callback',[...
    'A=str2num(get(hepgui.winsize_label,''String''));',...
    'if (length(A)==1) & (A(1) >= 1/HEP.srate) & (A<=HEP.ecg_dur_sec),',...
    'HEP.winsec=round(1000*A(1))/1000;',...
    'if A(1)+HEP.sec_ini>=HEP.ecg_dur_sec,',...
    'HEP.sec_ini=HEP.ecg_dur_sec-HEP.winsec;',...
    'set(hepgui.win_label,''String'',num2str(HEP.sec_ini));',...
    'set(hepgui.slider_arrow,''Value'',HEP.sec_ini);',...
    'end,',...
    'if HEP.ecg_dur_sec-HEP.winsec > 0,',...
    'set(hepgui.slider_arrow,''Max'',HEP.ecg_dur_sec-HEP.winsec);',...
    'else,',...
    'set(hepgui.slider_arrow,''Max'',0);',...
    'end,',...
    'HEP.ecg_handle=heplab_ecgplot(HEP.ecg,HEP.srate,HEP.qrs,HEP.sec_ini,',...
    'HEP.ecg_handle,HEP.winsec);',...
    'end,',...
    'set(hepgui.winsize_label,''String'',num2str(HEP.winsec));',...
    ]);

% right arrow
hepgui.rgt_arrow=uicontrol('Style','pushbutton',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'String','>',...
    'Position',[0.395551257253385 0.123456790123457 0.0203094777562863 0.259259259259259],...
    'Visible','on',...
    'parent',hepgui.slider_fr,...
    'Callback',[...
    'if HEP.sec_ini+HEP.winsec <= get(hepgui.slider_arrow,''Max''),',...
    'HEP.sec_ini=HEP.sec_ini+HEP.winsec;',...
    'else,',...
    'HEP.sec_ini=get(hepgui.slider_arrow,''Max'');',...
    'end,',...
    'set(hepgui.slider_arrow,''Value'',HEP.sec_ini);',...
    'HEP.ecg_handle=heplab_ecgplot(HEP.ecg,HEP.srate,HEP.qrs,HEP.sec_ini,',...
    'HEP.ecg_handle,HEP.winsec);',...
    'set(hepgui.win_label, ''String'',num2str(HEP.sec_ini));']);

%%%% PREVIEW IBIs %%%%
hepgui.preview_btn=uicontrol('Style','pushbutton',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'String','PREVIEW IBIs',...
    'Position',[0.368505195843325 0.0144356955380577 0.0991207034372502 0.0656167979002625],...
    'Visible','on',...
    'parent',hepgui.main,...
    'CallBack',[...
    'if ~isempty(HEP.qrs),',...
    'heplab_preview_IBIs;',...
    'else,',...
    'errordlg(''No cardiac events available!'');',...
    'end,',...
    ]);

%%%% SAVE EVENTS %%%%
hepgui.save_btn=uicontrol('Style','pushbutton',...
    'units','normalized',...
    'fontunits','points','fontsize',12,...
    'String','SAVE EVENTS',...
    'Position',[0.499600319744205 0.0144356955380577 0.0991207034372502 0.0656167979002625],...
    'Visible','on',...
    'parent',hepgui.main,...
    'CallBack',[...
    'if ~isempty(HEP.qrs),',...
    'heplab_save_events;',...
    'else,',...
    'errordlg(''No cardiac events available!'');',...
    'end,',...
    ]);

%%%% WindowButtonDownfcn %%%%
% Manually correct artifacts
set(hepgui.main, 'WindowButtonDownfcn',[...
    '[HEP.qrs]=heplab_edit_events(HEP.ecg,HEP.srate,HEP.qrs,HEP.ecg_handle,',...
    'HEP.sec_ini,HEP.winsec,HEP.ecg_dur_sec);',...
    'HEP.ecg_handle=heplab_ecgplot(HEP.ecg,HEP.srate,HEP.qrs,',...
    'HEP.sec_ini,HEP.ecg_handle,HEP.winsec);',...
    ]);

%%%% MENU %%%%
% menu labels
hepgui.menu_about = uimenu(hepgui.main,'Label','About');
hepgui.menu_edit = uimenu(hepgui.main,'Label','Edit');
hepgui.menu_tools = uimenu(hepgui.main,'Label','Tools');
hepgui.menu_help = uimenu(hepgui.main,'Label','Help');

% about submenu
hepgui.subm_about=uimenu(hepgui.menu_about,'Label','About HEPLAB',...
    'Callback','heplab_about');

% tools submenu
hepgui.subm_r_detect=uimenu(hepgui.menu_tools,'Label','Detect R waves');

% fastdetect
hepgui.subm_fastdetect=uimenu(hepgui.subm_r_detect,'Label','ecglab fast',...
    'CallBack',	[...
    'HEP.qrs = heplab_fastdetect(HEP.ecg,HEP.srate);'...
    'HEP.ecg_handle=heplab_ecgplot(HEP.ecg,HEP.srate,HEP.qrs,HEP.sec_ini,',...
    'HEP.ecg_handle,HEP.winsec);']);

% slowdetect
hepgui.subm_slowdetect=uimenu(hepgui.subm_r_detect,'Label','ecglab slow',...
    'CallBack',	[...
    'HEP.qrs = heplab_slowdetect(HEP.ecg,HEP.srate);'...
    'HEP.ecg_handle=heplab_ecgplot(HEP.ecg,HEP.srate,HEP.qrs,HEP.sec_ini,',...
    'HEP.ecg_handle,HEP.winsec);']);

% Pan-Tompkins
hepgui.subm_pan_tompkin=uimenu(hepgui.subm_r_detect,'Label','Pan-Tompkin',...
    'CallBack',	[...
    '[amp,HEP.qrs] = heplab_pan_tompkin(HEP.ecg,HEP.srate);'...
    'if size(HEP.qrs,1)<size(HEP.qrs,2); HEP.qrs = HEP.qrs''; end;'...
    'HEP.ecg_handle=heplab_ecgplot(HEP.ecg,HEP.srate,HEP.qrs,HEP.sec_ini,',...
    'HEP.ecg_handle,HEP.winsec);']);

% detect T wave
hepgui.subm_detect_twave=uimenu(hepgui.menu_tools,'Label','Detect T waves',...
    'CallBack',	[...
    '[R,Q,S,T,P_w] = heplab_T_detect_MTEO(HEP.ecg,HEP.srate,0);'...
    'HEP.qrs = T(:,1);'...
    'HEP.ecg_handle=heplab_ecgplot(HEP.ecg,HEP.srate,HEP.qrs,HEP.sec_ini,',...
    'HEP.ecg_handle,HEP.winsec);'...
    'clear R Q S T P_w']);

% edit submenu
% load ecg from eeglab
hepgui.subm_reload_ecg=uimenu(hepgui.menu_edit,'Label','Load ECG from eeglab',...
    'CallBack','pop_heplab');

% load ecg from .mat fle
hepgui.subm_reload_ecg=uimenu(hepgui.menu_edit,'Label','Load ECG from .mat file',...
    'CallBack','heplab_load_ECG');

% clear events
hepgui.subm_clear_events=uimenu(hepgui.menu_edit,'Label','Clear events',...
    'CallBack',	[...
    'if isfield(HEP,''qrs'') && ~isempty(HEP.qrs),',...
    'HEP.qrs = [];',...
    'HEP.ecg_handle=heplab_ecgplot(HEP.ecg,HEP.srate,HEP.qrs,HEP.sec_ini,',...
    'HEP.ecg_handle,HEP.winsec);',...
    'else,',...
    'errordlg (''No cardiac events found!'');',...
    'end,',...
    ]);

% save hep
hepgui.subm_save_hep=uimenu(hepgui.menu_edit,'Label','Save HEP',...
    'Callback', [...
    'HEP.savefilename = inputdlg(''Select a filename for the HEP variable'','...
    '''Save HEP'');',...
    'save([HEP.savefilename{1} ''.mat''],''HEP'');'...
    ]);

% load hep
hepgui.subm_load_hep=uimenu(hepgui.menu_edit,'Label','Load HEP',...
    'CallBack', 'heplab_load_HEP');

% help submenu
hepgui.subm_help=uimenu(hepgui.menu_help,'Label','Visit the GitHub page',...
    'Callback','web(''https://github.com/perakakis/HEPLAB'',''-browser'')');