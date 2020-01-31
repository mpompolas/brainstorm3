function varargout = process_event_detect_bad_channels_MOTOR_LAB( varargin )
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
    sProcess.Comment     = 'Detect Noisy Channels';
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
    sProcess.options.eventname.Value   = 'Noise';
    % Channel name
    sProcess.options.channelgroup.Comment = 'Channel Groups or Names: ';
    sProcess.options.channelgroup.Type    = 'text';
    sProcess.options.channelgroup.Value   = 'LFP1, LFP2';
    % Channel name comment
    sProcess.options.channelhelp.Comment = 'Select the group of channels: "LFP1" or "LFP1,LFP2", or "All" or "LFP1_1, LFP1_2, LFP1_3"';
    sProcess.options.channelhelp.Type    = 'label';
    % Threshold
    sProcess.options.threshold.Comment = 'Amplitude threshold: ';
    sProcess.options.threshold.Type    = 'value';
    sProcess.options.threshold.Value   = {1, ' std', 1};
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
        
        %% Check which channels to load
        % Load channel file
        ChannelMat = in_bst_channel(sInputs(iFile).ChannelFile);
        
        target = sProcess.options.channelgroup.Value;
        if ~iscell(target)
            if any(target == ',') || any(target == ';')
                % Split string based on the commas
                target = strtrim(str_split(target, ',;'));
            else
                target = {strtrim(target)};
            end
        end


        % Check if All channels was selected
        if strcmp(sProcess.options.channelgroup.Value,'All')
            iChannels = 1:length(ChannelMat.Channel);
        else % Check for Names
            iChannels = channel_find(ChannelMat.Channel, sProcess.options.channelgroup.Value);
        end
        
        % Else check for Groups
        DataMat_channelFlag = in_bst_data(sInputs(iFile).FileName, 'ChannelFlag');
        if isempty(iChannels) 
            allGroups = upper(unique({ChannelMat.Channel.Group}));
            % Process all the targets
            for i = 1:length(target)
                % Search by type: return all the channels from this Group
                if ismember(upper(strtrim(target{i})), allGroups)
%                         iChan = good_channel(ChannelMat.Channel, [], target{i});

                    iChan = [];
                    for iChannel = 1:length(ChannelMat.Channel)
                        % Get only good channels
                        if strcmp(upper(strtrim(target{i})), upper(strtrim(ChannelMat.Channel(iChannel).Group))) && DataMat_channelFlag.ChannelFlag(iChannel) == 1
                            iChan = [iChan, iChannel];
                        end
                    end                             
                end
                % Comment
                if ~isempty(iChan)
                    iChannels = [iChannels, iChan];
%                         if ~isempty(Comment)
%                             Comment = [Comment, ', '];
%                         end
%                         Comment = [Comment, target{i}];
                else
                    bst_error('No channels were selected. Make sure that the Group name is spelled properly. Also make sure that not ALL channels in that bank are marked as BAD')
                end
            end
            % Sort channels indices, and remove duplicates
            iChannels = unique(iChannels);
        end
        
        
        
        
        if isempty(iChannels)
            bst_report('Error', sProcess, sInputs(iFile), ['Channel Group or Name: "' chanName '" not found in the channel file.']);
            stop
        end
        
        
        
        %%
        % Process only continuous files
        if ~isempty(sFile.epochs)
            bst_report('Error', sProcess, sInputs(iFile), 'This function can only process continuous recordings (no epochs).');
            continue;
        end
        
        iChanWeights = 1;
        % Read channel to process
        if ~isempty(TimeWindow)
            SamplesBounds = round(sFile.prop.times(1)*sFile.prop.sfreq) + bst_closest(TimeWindow, DataMat.Time) - 1;
        else
            SamplesBounds = [];
            TimeWindow = sFile.prop.times;
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
        
        
        % ===== DETECT PEAKS =====
        % Progress bar
        bst_progress('text', 'Detecting peaks...');
        bst_progress('set', progressPos + round(2 * iFile / length(sInputs) / 3 * 100));
        % Perform detection
        detectedEvt = Compute(F, TimeVector, OPTIONS);

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
            iEvt = find(strcmpi({sFile.events.label}, [newName '_' chanGroup num2str(i)]));
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
            sEvent.times    = detectedEvt{i}/sFile.prop.sfreq + TimeWindow(1);
            sEvent.epochs   = ones(1, size(sEvent.times,2));
            sEvent.channels = cell(1, size(sEvent.times,2));
            sEvent.notes    = cell(1, size(sEvent.times,2));
            
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
function evt = Compute(F, TimeVector, OPTIONS)
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
    
    evt = cell(1,size(F,1));
    
    % Get the global threshold
    global_std  = mean(std(F,[],2));
    global_mean = mean(mean(F));
    
    global_threshold = abs(global_mean) + OPTIONS.threshold * global_std;
    
    mask = abs(F) > global_threshold;
    
    for iChannel = 1:size(F,1)
        
        
        
        FINISH THIS
        
        
    end
    
    
    % Plot the results - This in general should be commented out
    % Left it here for threshold visualization
    possible_plot_positions = {'northwest', 'northeast', 'southwest', 'southeast'};

    for iChannel = 30:33
        f = figure(iChannel); 
        if iChannel<5
            movegui(f,possible_plot_positions{iChannel});
        end
        drawnow;
        plot(TimeVector,F(iChannel,:));
        hold on; title 'Event maximum force';
        plot(TimeVector(evt{iChannel}),F(iChannel,evt{iChannel}),'r*'); 
        plot(TimeVector, ones(1,length(TimeVector)) * OPTIONS.threshold*std(abs(F(iChannel,:))))
        hold off; drawnow;
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
            


