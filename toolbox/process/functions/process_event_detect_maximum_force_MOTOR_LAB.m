function varargout = process_event_detect_maximum_force( varargin )
%
% USAGE:  OutputFiles = process_evt_detect('Run', sProcess, sInputs)
%                 evt = process_evt_detect('Compute', F, TimeVector, OPTIONS, Fmask)
%                 evt = process_evt_detect('Compute', F, TimeVector, OPTIONS)
%             OPTIONS = process_evt_detect('Compute')                                : Get the default options structure
%   [iCh, iChWeights] = process_evt_detect('ParseChannelMontage', strMontage, ChannelNames)

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2016 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Konstantinos Nasiotis 2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Detect maximum force events from a single channel';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'Dancause Lab', 'Events'};
    sProcess.Index       = 1880;
    sProcess.Description = 'http://neuroimage.usc.edu/brainstorm/Tutorials/ArtifactsDetect#Custom_detection';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Time window
    sProcess.options.timewindow.Comment   = 'Time window: ';
    sProcess.options.timewindow.Type      = 'timewindow';
    sProcess.options.timewindow.Value     = [];
    sProcess.options.timewindow.InputTypes = {'raw'};
    % Event name
    sProcess.options.eventname.Comment = 'Event name: ';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = 'Maximum force';
    % Separator
    sProcess.options.separator.Type = 'separator';
    sProcess.options.separator.Comment = ' ';
    % Channel name
    sProcess.options.channelgroup.Comment = 'Channel Group: ';
    sProcess.options.channelgroup.Type    = 'text';
    sProcess.options.channelgroup.Value   = 'SGMx';
    % Channel name comment
    sProcess.options.channelhelp.Comment = 'Select the group of channels';
    sProcess.options.channelhelp.Type    = 'label';
    % Threshold
    sProcess.options.threshold.Comment = 'Amplitude threshold: ';
    sProcess.options.threshold.Type    = 'value';
    sProcess.options.threshold.Value   = {1, ' std', 2};
    % Threshold
    sProcess.options.threshold_width.Comment = 'Width threshold: ';
    sProcess.options.threshold_width.Type    = 'value';
    sProcess.options.threshold_width.Value   = {100, ' ms', []};
    % Blanking period
    sProcess.options.blanking.Comment = 'Min duration between two events: ';
    sProcess.options.blanking.Type    = 'value';
    sProcess.options.blanking.Value   = {1000, 'ms', []};

end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = ['Detect: ', sProcess.options.eventname.Value];
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>   
    % ===== GET OPTIONS =====
    % Event name
    evtName = strtrim(sProcess.options.eventname.Value);
    chanGroup = strtrim(sProcess.options.channelgroup.Value);
    if isempty(evtName) || isempty(chanGroup)
        bst_report('Error', sProcess, [], 'Event and channel names must be specified.');
        OutputFiles = {};
        return;
    end
    % Ignore bad segments? (not in the options: always enforced)
    isIgnoreBad = 1;
    % Prepare options structure for the detection function
    OPTIONS = Compute();
    OPTIONS.threshold       = sProcess.options.threshold.Value{1};
    OPTIONS.blanking        = sProcess.options.blanking.Value{1};
    OPTIONS.threshold_width = sProcess.options.threshold_width.Value{1};
    if isfield(sProcess.options,'maxcross')
        OPTIONS.maxcross   = sProcess.options.maxcross.Value;
    end
    if isfield(sProcess.options,'ismaxpeak')
        OPTIONS.ismaxpeak   = sProcess.options.ismaxpeak.Value;
    end
    % Time window to process
    if isfield(sProcess.options, 'timewindow') && isfield(sProcess.options.timewindow, 'Value') && iscell(sProcess.options.timewindow.Value) && ~isempty(sProcess.options.timewindow.Value)
        TimeWindow = sProcess.options.timewindow.Value{1};
    else
        TimeWindow = [];
    end
    
    % Get current progressbar position
    progressPos = bst_progress('get');
    nEvents = 0;
    nTotalOcc = 0;
    
    % For each file
    iOk = false(1,length(sInputs));
    for iFile = 1:length(sInputs)
        % ===== GET DATA =====
        % Progress bar
        bst_progress('text', 'Reading channels to process...');
        bst_progress('set', progressPos + round(iFile / length(sInputs) / 3 * 100));
        % Load the raw file descriptor
        isRaw = strcmpi(sInputs(iFile).FileType, 'raw');
        if isRaw
            DataMat = in_bst_data(sInputs(iFile).FileName, 'F', 'Time');
            sFile = DataMat.F;
        else
            DataMat = in_bst_data(sInputs(iFile).FileName, 'Time');
            sFile = in_fopen(sInputs(iFile).FileName, 'BST-DATA');
        end
        % Load channel file
        ChannelMat = in_bst_channel(sInputs(iFile).ChannelFile);
        % Process only continuous files
        if ~isempty(sFile.epochs)
            bst_report('Error', sProcess, sInputs(iFile), 'This function can only process continuous recordings (no epochs).');
            continue;
        end
        % Get channel to process: multiple channels
        iChannels = [];
        for iChannel = 1:length(ChannelMat.Channel)
            if strfind(ChannelMat.Channel(iChannel).Name, chanGroup)
                iChannels = [iChannels iChannel];
            end
        end
        if isempty(iChannels)
            bst_report('Error', sProcess, sInputs(iFile), ['Group channel "' chanName '" not found in the channel file.']);
            stop
        end
        iChanWeights = 1;
        % Read channel to process
        if ~isempty(TimeWindow)
            SamplesBounds = round(sFile.prop.times(1)*sFile.prop.sfreq) + bst_closest(TimeWindow, DataMat.Time) - 1;
        else
            SamplesBounds = [];
        end
        [F, TimeVector] = in_fread(sFile, ChannelMat, 1, SamplesBounds, iChannels);
        % Apply weights if reading multiple channels
        if (length(iChannels) > 1)
            F = iChanWeights * F;
        end
        % If nothing was read
        if isempty(F) || (length(TimeVector) < 2)
            bst_report('Error', sProcess, sInputs(iFile), 'Time window is not valid.');
            continue;
        end
        
        % ===== BAD SEGMENTS =====
        % If ignore bad segments
        Fmask = [];
        if isIgnoreBad
            % Get list of bad segments in file
            badSeg = panel_record('GetBadSegments', sFile);
            % Adjust with beginning of file
            badSeg = badSeg - sFile.prop.times(1)*sFile.prop.sfreq + 1;
            if ~isempty(badSeg)
                % Create file mask
                Fmask = true(size(F));
                % Loop on each segment: mark as bad
                for iSeg = 1:size(badSeg, 2)
                    Fmask(badSeg(1,iSeg):badSeg(2,iSeg)) = false;
                end
            end
        end
        
        % ===== DETECT PEAKS =====
        % Progress bar
        bst_progress('text', 'Detecting peaks...');
        bst_progress('set', progressPos + round(2 * iFile / length(sInputs) / 3 * 100));
        % Perform detection
        detectedEvt = Compute(F, TimeVector, OPTIONS, Fmask);

        % ===== CREATE EVENTS =====
        sEvent = [];
        % Basic events structure
        if ~isfield(sFile, 'events') || isempty(sFile.events)
            sFile.events = repmat(db_template('event'), 0);
        end
        % Process each event type separately
        for i = 1:length(detectedEvt)
            % Event name
            if (i > 1)
                newName = sprintf('%s%d', evtName, i);
            else
                newName = evtName;
            end
            % Get the event to create
            iEvt = find(strcmpi({sFile.events.label}, newName));
            % Existing event: reset it
            if ~isempty(iEvt)
                sEvent = sFile.events(iEvt);
                sEvent.epochs  = [];
                sEvent.times   = [];
                sEvent.reactTimes = [];
            % Else: create new event
            else
                % Initialize new event
                iEvt = length(sFile.events) + 1;
                sEvent = db_template('event');
                sEvent.label = newName;
                % Set the default color for this new event
                sEvent.color = rand(1,3);
                sEvent.label = [newName '_' chanGroup num2str(i)];
            end
            % Times, samples, epochs
            sEvent.times   = detectedEvt{i}/sFile.prop.sfreq + TimeWindow(1);
%             sEvent.samples = round(sEvent.times .* sFile.prop.sfreq);
            sEvent.epochs  = ones(1, size(sEvent.times,2));
            % Add to events structure
            sFile.events(iEvt) = sEvent;
            nEvents = nEvents + 1;
            nTotalOcc = nTotalOcc + size(sEvent.times, 2);
        end
        
        % ===== SAVE RESULT =====
        % Progress bar
        bst_progress('text', 'Saving results...');
        bst_progress('set', progressPos + round(3 * iFile / length(sInputs) / 3 * 100));
        % Only save changes if something was detected
        if ~isempty(sEvent)
            % Report changes in .mat structure
            if isRaw
                DataMat.F = sFile;
            else
                DataMat.Events = sFile.events;
            end
            DataMat = rmfield(DataMat, 'Time');
            % Save file definition
            bst_save(file_fullpath(sInputs(iFile).FileName), DataMat, 'v6', 1);
            % Report number of detected events
            bst_report('Info', sProcess, sInputs(iFile), sprintf('%s: %d events detected in %d categories', chanGroup, nTotalOcc, nEvents));
        else
            bst_report('Warning', sProcess, sInputs(iFile), ['No event detected on channel "' chanGroup '". Please check the signal quality.']);
        end
        iOk(iFile) = true;
    end
    % Return all the input files
    OutputFiles = {sInputs(iOk).FileName};
end


%% ===== PERFORM DETECTION =====
% USAGE:      evt = Compute(F, TimeVector, OPTIONS, Fmask)
%             evt = Compute(F, TimeVector, OPTIONS)
%         OPTIONS = Compute()                              : Get the default options structure
function evt = Compute(F, TimeVector, OPTIONS, Fmask)
    % Options structure
    defOptions = struct('bandpass',     [10, 40], ...   % Filter the signal before performing the detection, [highpass, lowpass]
                        'threshold',    2, ...          % Create an event if the value goes > threshold * standard deviation
                        'blanking',     .5, ...         % No events can be detected during the blanking period
                        'maxcross',     10, ...         % Max number of bounces accepted in one blanking period (to ignore high-frequency oscillations)
                        'ampmin',       0, ...          % Minimum absolute value accepted for a detected peak
                        'isnoisecheck', 1, ...          % If 1, perform a noise quality check on the detected events
                        'noisethresh',  2.5, ...        %    => Noise threshold (x standard deviation or the rms)
                        'isclassify',   1, ...          % If 1, classify the events in different morphological categories
                        'corrval',      .8, ...         %    => Correlation threshold
                        'ismaxpeak',    1);             % If 1, the max point defines the event, else, first thresh crossing defines the event 
    % Parse inputs
    if (nargin == 0)
        evt = defOptions;
        return;
    end
    if (nargin < 4)
        Fmask = [];
    end
    % Copy the missing parameters
    OPTIONS = struct_copy_fields(OPTIONS, defOptions, 0);
    % Sampling frequency
    sFreq = 1 ./ (TimeVector(2) - TimeVector(1));
    % Convert blanking period to number of samples
    blankSmp = round(OPTIONS.blanking * sFreq);
    % Initialize output
    evt = {};
    % If blanking period longer than the signal to process: exit
    if (blankSmp >= length(F))
        bst_report('Warning', 'process_evt_detect', [], 'The blanking period between two events is longer than the signal. Cannot perform detection.');
        return;
    end
    
    
    %% Magic happens here
    
    % Filter the signals
    OPTIONS.bandpass = [0.1 40];
    [b,a] = butter(2, [OPTIONS.bandpass(1) OPTIONS.bandpass(2)]./(sFreq/2),'bandpass');
    F_filtered = filtfilt(b,a,F')';
    
    F_filtered = F;

    evt = cell(1,size(F_filtered,1));
    
    for iChannel = 1:size(F_filtered,1)
        [maximum_force, evt{iChannel}] = findpeaks(abs(F_filtered(iChannel,:)),'MinPeakHeight', OPTIONS.threshold*std(abs(F_filtered(iChannel,:))),...
                                                                               'MinPeakDistance', round(sFreq*OPTIONS.blanking),...
                                                                               'MinPeakWidth', round(sFreq*OPTIONS.threshold_width/1000));
%         evt{iChannel} = event_maximum_force/sFreq + TimeVector(1);
    end
       
    
    for iChannel = 1:size(F,1)
        figure(iChannel); plot(TimeVector(1:end),F(iChannel,:))
        hold on; title 'Event maximum force';
        plot(TimeVector(evt{iChannel}),F(iChannel,evt{iChannel}),'r*'); hold off
    end

end


%% ===== PARSE CHANNEL MONTAGE =====
function [iChannels, iChanWeights] = ParseChannelMontage(strMontage, ChannelNames)
    % Split with ','
    sline = str_split(strMontage, ',');
    % Inialize list of channels
    iChannels = zeros(1, length(sline));
    iChanWeights = zeros(1, length(sline));
    % Loop on all the entries
    for i = 1:length(sline)
        % Split with '*'
        schan = str_split(strtrim(sline{i}), '*');
        % No multiplication: "Cz" or "-Cz" or "+Cz"
        if (length(schan) == 1)
            schan = strtrim(schan{1});
            if (schan(1) == '+')
                chfactor = 1;
                chname = schan(2:end);
            elseif (schan(1) == '-')
                chfactor = -1;
                chname = schan(2:end);
            else
                chfactor = 1;
                chname = schan;
            end
        % One multiplication: "<factor>*<chname>"
        elseif (length(schan) == 2)
            chfactor = str2num(strtrim(schan{1}));
            chname = strtrim(schan{2});
        else
            iChannels = [];
            iChanWeights = [];
            return;
        end
        % Look for existing channel name
        iChan = find(strcmpi(ChannelNames, chname));
        if isempty(iChan)
            iChannels = [];
            iChanWeights = [];
            return;
        end
        % If not referenced yet: add new channel entry
        iChannels(i) = iChan;
        iChanWeights(i) = chfactor;
    end
    % Sort channels
    [iChannels,I] = sort(iChannels);
    iChanWeights = iChanWeights(I);
end
            


