function [status, finalStepPath, preproParams] = f_mainPreproRS(databasePath, step, varargin)
%Script that performs the main RS preprocessing to the desired database
%INPUTS:
%   NOTE: The databasePath MUST already be in a BIDS-like structure
%step = 'all' if you want to run ALL the steps for each subject (e.g. run all the steps for subject 1, then subject 2 and so on);
%   or a specific step that you want to run (as a vector or int) ('all' by default)
%   NOTE: If a specific step is given, that step will ONLY be run over the available subjects of the previous step
%OPTIONAL INPUTS:
%BIDSmodality       = String with the modality of the data that will be analyzed (used in sub-#_BIDStask_BIDSmodality.set) ('eeg' by default)
%BIDStask           = String with the task to analyze (used in sub-#_BIDStask_BIDSmodality.set) ('task-rest by default')
%newPath            = String with the path in which the new folders will be stored (databasePath/analysis by default)
%initialSub         = Integer corresponding to the subject in which the user desires to start (1 by default)
%filterAndResample  = true if the user wants to filter and resample the data before running the Step0 (true by default). (Runs f_optStep0FilterAndResample)
%newSR              = Integer with the new sampling rate desired in Hz (512 by default)
%freqRange          = Vector of [2, 1] with the range of frequencies [lowcut, highcut] that want to be kept ([0.5, 40]Hz by default)
%reref_REST         = true if the user wants to re-reference the data using REST, in addition to average referencing (false by default)
%burstCriterion     = Data portions with variance larger than the calibration data will be marked for ASR correction
%                   (lower is more strict, default: 5)
%windowCriterion    = Maximum proportion of noisy channels after ASR correction. 
%                   If it surpasses it, removes the time window. (lower is more strict, default: 0.25) (Common ranges: 0.05-0.3)
%onlyBlinks         = true if wants to remove blinks only. false if wants to remove all eye artifacts (false by default)
%
%OUTPUTS:
%status             = 1 if the script was completed succesfully. 0 otherwise
%finalStepPath      = Path were the final .sets are expected to be (if status is 0, returns an empty array)
%preproParams       = Parameters used in the pre-processing pipeline (if status is 0, returns an empty array)
%Author: Jhony Mejia
%--------------------------------------------------------------------------
%DISCLAIMER: Most of the implementations of this script were produced by other researchers
%EEGLAB: Delorme, A., & Makeig, S. (2004). EEGLAB: an open source toolbox for analysis of single-trial EEG dynamics including independent component analysis. Journal of neuroscience methods, 134(1), 9-21
%REST: Li Dong*, Fali Li, Qiang Liu, Xin Wen, Yongxiu Lai, Peng Xu and Dezhong Yao*. MATLAB Toolboxes for Reference Electrode Standardization Technique (REST) of Scalp EEG. Frontiers in Neuroscience, 2017:11(601).
%clean_rawdata & ASR: Kothe & Makeig, 2013 BCILAB: A platform for Brain�Computer interface development
%ICLabel: Pion-Tonachini, L., Kreutz-Delgado, K., & Makeig, S. (2019). ICLabel: An automated electroencephalographic independent component classifier, dataset, and website. NeuroImage, 198, 181�197.
%EyeCatch: Bigdely-Shamlo, Nima, Kenneth Kreutz-Delgado, Christian Kothe, and Scott Makeig. "EyeCatch: Data-mining over half a million EEG independent components to construct a fully-automated eye-component detector." In Engineering in Medicine and Biology Society (EMBC), 2013 35th Annual International Conference of the IEEE, pp. 5845-5848. IEEE, 2013.
%BLINKER: Kleifges K, Bigdely-Shamlo N, Kerick S, and Robbins KA. BLINKER: Automated extraction of ocular indices from EEG enabling large-scale analysis. Front. Neurosci. 11:12. doi: 10.3389/fnins.2017.00012.
%--------------------------------------------------------------------------

%Defines default outputs
status = 0;
finalStepPath = '';
preproParams = '';

%Checks that the user has eeglab
try
    version = eeg_getversion;
catch
    %If eeglab has not been executed, try executing it to enable all eeglab functions, and ask for the version again.
    try
        eeglab;
        close;
        clc;
        version = eeg_getversion;
    catch
        disp('ERROR: It seems that you do not have EEGLab. Please download and install it');
        disp('https://sccn.ucsd.edu/eeglab/download.php');
        disp('https://eeglab.org/tutorials/01_Install/Install.html');
        return;
    end
end
%Checks that the EEGLab version is newer than 2020
if str2double(version) < 2020
    disp('ERROR: These scripts were built using EEGLab v.2020.0');
    disp('Most of the functions can work with older versions of EEGLab, but it is suggested that you have a version from 2020 or newer');
    return;
end


%Defines the default optional parameters
if nargin < 2 
    step = 'all';
end
%Type help finputcheck to know more about it. Basically it takes the inputs, makes sure everything is okay 
%and puts that information as a structure
params = finputcheck( varargin, {'BIDSmodality',        'string',       '',         'eeg'; ...
                                'BIDStask',             'string',       '',         'task-rest';
                                'newPath',              'string',       '',         fullfile(databasePath, 'analysis_RS');
                                'initialSub',           'float',        [1, inf],   1;
                                'filterAndResample',    'boolean',      '',         true;
                                'newSR',                'float',        [64, inf],  512;
                                'freqRange',            'integer',      [],         [0.5, 40];
                                'reref_REST',           'boolean',      '',         false;
                                'burstCriterion',       'float',        [0, inf],   5;
                                'windowCriterion',      'float',        [0, inf],   0.25;
                                'onlyBlinks',           'boolean',      '',         false
                                } ...
                                );

%Checks that the defaults where properly created
if ischar(params) && startsWith(params, 'error:')
    disp(params);
    return
end


%Checks that the database exists
if ~exist(databasePath, 'dir')
    disp('ERROR: The given path does not exist. Please enter a valid folder name');
    return
end

%Checks that the folder has a BIDS-like structure
%MUST have a 'README.md', 'participants.tsv', 'task_modality.json' and folders that start with 'sub-'
mainDir = dir(databasePath);
mainDirNames = {mainDir(:).name};
if (sum(strcmp(mainDirNames, 'README.md')) * sum(strcmp(mainDirNames, 'participants.tsv')) ...
    * sum(strcmp(mainDirNames, strcat(params.BIDStask, '_', params.BIDSmodality, '.json'))) * sum(startsWith(mainDirNames, 'sub-'))) == 0
    disp('ERROR: Please check that the folder you gave has a BIDS-like structure');
    disp('It MUST have the following files:');
    disp(strcat('README.md, participants.tsv, ', params.BIDStask, '_', params.BIDSmodality, '.json and folders that start with sub-'));
    disp('Also check that the BIDSmodality and BIDStask that you entered are the ones you are interested in');
    return
end

%Adds the path that contains the functions used in the pre-processing, and the paths to update the .json or .tsv
addpath(genpath('Functions'));

%If everything is okay, start by checking if the .sets have already been re-referenced
%To do so, opens the .json and sees if the events were already referenced
fid = fopen(fullfile(databasePath, strcat(params.BIDStask, '_', params.BIDSmodality, '.json')));
raw = fread(fid, inf);
str = char(raw');
fclose(fid);
taskInfo = jsondecode(str);
isReferenced = false;
if (strcmpi(taskInfo.EEGReference, 'Avg')) || strcmpi(taskInfo.EEGReference, 'Average') || strcmpi(taskInfo.EEGReference, 'averef')
    isReferenced = true;  
end


%If the analysis folder does not exist, create it
if ~exist(params.newPath, 'dir')
    mkdir(params.newPath);
end

%If the parameters.txt does not exit, create it
if ~exist(fullfile(params.newPath, 'parameters.txt'), 'file')
    fileID = fopen(fullfile(params.newPath, 'parameters.txt'), 'w');
    fprintf(fileID, 'This txt contains the parameters used to create the .set located in the following path:\n');
    fprintf(fileID, '%s \n \n', fullfile(params.newPath));
    fprintf(fileID, 'General parameters: \n');
    fprintf(fileID, '\t - BIDSmodality = %s \n', params.BIDSmodality);
    fprintf(fileID, '\t - BIDStask = %s \n', params.BIDStask);
    fprintf(fileID, '\t - newPath = %s \n', params.newPath);
    fprintf(fileID, '-----------------------------------Preprocessing-----------------------------------------\n \n');
    fclose(fileID);
end

%Checks that the initial subject is less or equal than the total number of subjects
subjFolders = startsWith(mainDirNames, 'sub-');
subjFolders = mainDirNames(subjFolders);
nSubj = length(subjFolders);
if params.initialSub > nSubj
    fprintf('ERROR: The initial subject index given was %d, but there are only %d subjects \n', params.initialSub, nSubj);
    return
end

contStep0 = 0;          %Iterator to know how many subjects have the step 0 (Optional filtering and resampling) completed
contStep1 = 0;          %Iterator to know how many subjects have the step 1 (Identification of bad channels) completed
contStep2 = 0;          %Iterator to know how many subjects have the step 2 (Average reference) completed
contStep3 = 0;          %Iterator to know how many subjects have the step 3 (Artifact rejection) completed
contStep4 = 0;          %Iterator to know how many subjects have the step 4 (Computation of ICA) completed
contStep5 = 0;          %Iterator to know how many subjects have the step 5 (Components rejection) completed
contStep6 = 0;          %Iterator to know how many subjects have the step 6 (Interpolation of bad channels) completed

%Starts the whole preprocesing pipeline for all subjects of the given database
databaseName = regexp(databasePath, filesep, 'split');
databaseName = databaseName{end};
disp('****************************************************************************');
fprintf('Preprocessing the database %s \n', databaseName);
disp('****************************************************************************');
for i = params.initialSub:nSubj
    %Defines the name of the current subject
    iSubName = subjFolders{i};
    iSetPath = fullfile(databasePath, iSubName, params.BIDSmodality);
    iSetName = dir(fullfile(iSetPath, '*.set'));
    iSetName = iSetName(1).name;
    
    %Asks the user if it wants to continue with the next subject
    if i > params.initialSub && (ismember(1, step) || strcmp(step, 'all'))       %If it is the step 1, a lot of input from the user is required
        disp('Do you want to continue with the next subject? (y/n)');
        nextSubj = input('', 's');
        if ~strcmpi(nextSubj, 'y')
            break
        end
    end
    
    %Print to have a track of which subject is being analyzed
    disp('----------------------------------------------------------------------------');
    disp('----------------------------------------------------------------------------');
    fprintf('Pre processing subject %s (%d/%d) \n', iSubName, i, nSubj);
    
    
    
    %% Step 0: Optional re-referencing and resampling
    %Defines the path in which this step will (or should already) be saved
    iPathStep0 = fullfile(params.newPath, 'Preprocessing', 'Step0_optFilterAndResample', iSubName, params.BIDSmodality);
    iNameStep0 = strcat('s0_', iSetName);
    
    %If the desired .set does not exist, and the user wants to run this step, run the analysis
    if ~exist(fullfile(iPathStep0, iNameStep0), 'file') && (ismember(0, step) || strcmp('all', step))
        disp('--------------Starting Step 0 (Optional Filter and Resample)----------------');
        if ~exist(iPathStep0, 'dir')
            mkdir(iPathStep0);
        end
        
        %If the user wants to filter and resample the data, do it
        if params.filterAndResample
            %Filters and resamples the data
            [status, EEG] = f_optStep0FilterAndResample(iSetPath, iSetName, params.newSR, params.freqRange);

            %Checks that the script was completed succesfully
            if status == 0
                disp('WARNING: Could not complete the Optional Step 0: Resampling and filtering. Continuing with the next subject');
                continue;
            end
            
            %Add a new row to the .comments field, mentioning the parameters used for this step
            iComment = sprintf('Step 0: filterAndResample = true ; newSR = %d ; freqRange = [%.1f, %.1f] ', params.newSR, params.freqRange);
            EEG.comments = strvcat(EEG.comments, iComment);
                
            %If everything was okay, save the filtered and resampled .set
            pop_saveset(EEG, 'filename', iNameStep0, 'filepath', iPathStep0);

            
        %Otherwise, just copy the original .set into the step0 path and name
        else
            EEG = pop_loadset('filename', iSetName, 'filepath', iSetPath);
            
            %Add a new row to the .comments field, mentioning the parameters used for this step
            iComment = sprintf('Step 0: filterAndResample = false ');
            EEG.comments = strvcat(EEG.comments, iComment);
            
            pop_saveset(EEG, 'filename', iNameStep0, 'filepath', iPathStep0);
        end
        
        %Updates the parameters.txt with the parameters used
        statusUpdate = f_updateParametersTxtRS('filterAndResample', params);
        if statusUpdate == 0
            disp('WARNING: Could not update the parameters.txt');
        end
        
        %If it reached this line, then the step 0 was properly completed for the i-th subject
        contStep0 = contStep0 +1;
        disp('----------------------------Step 0 completed--------------------------------');

    elseif (ismember(0, step) || strcmp('all', step))
        %If the file for step 0 already exists, and the user wants to run this step, let the user know and add to the iterator
        disp('This subject already had the step 0 files (HEP marks)');
        contStep0 = contStep0 +1;
    end
    
    
    
    %% Step 1: Selecting/identifying bad channels
    %Defines the path in which this step will (or should already) be saved
    iPathStep1 = fullfile(params.newPath, 'Preprocessing', 'Step1_BadChansIdentification', iSubName, params.BIDSmodality);
    iNameStep1 = strcat('s1_', iSetName(1:end-3), 'mat');
    
    %If the desired .set does not exist, and the user wants to run this step, run the analysis
    if ~exist(fullfile(iPathStep1, iNameStep1), 'file') && (ismember(1, step) || strcmp('all', step))
        disp('----------------Starting Step 1 (Identifying bad channels)------------------');
        if ~exist(iPathStep1, 'dir')
            mkdir(iPathStep1);
        end
              
        %First, check that the files for step0 exist
        if ~exist(fullfile(iPathStep0, iNameStep0), 'file')
            disp('WARNING: This subject does not have the files corresponding to Step 0. Skipping to the next subject');
            continue
        end
        
        %Checks if the channels.tsv file exists, and loads its' information
        if exist(fullfile(iSetPath, strcat(iSubName, '_', params.BIDStask, '_channels.tsv')), 'file')
            %Loads the .tsv
            copyfile(fullfile(iSetPath, strcat(iSubName, '_', params.BIDStask, '_channels.tsv')), fullfile(iPathStep1, strcat(iSubName, '_', params.BIDStask, '_channels.txt')));
            iChanTable = readtable(fullfile(iPathStep1, strcat(iSubName, '_', params.BIDStask, '_channels.txt')));
            movefile(fullfile(iPathStep1, strcat(iSubName, '_', params.BIDStask, '_channels.txt')), fullfile(iPathStep1, strcat(iSubName, '_', params.BIDStask, '_channels.tsv')));
            
            %Runs the script to let the user rely on the database information, or check the channels themselves
            [badChanIdxs, badChanLbls] = f_step1IdBadChannels(iPathStep0, iNameStep0, iChanTable);
        else
            %If the tsv does not exist, the user MUST identify bad channels themselves
            [badChanIdxs, badChanLbls] = f_step1IdBadChannels(iPathStep0, iNameStep0);
        end
        
        %Save the .mat
        save(fullfile(iPathStep1, iNameStep1), 'badChanIdxs', 'badChanLbls');
        contStep1 = contStep1 +1;
        
        disp('----------------------------Step 1 completed--------------------------------');
    elseif (ismember(1, step) || strcmp('all', step))
        %If the file for step 1 already exists, let the user know and add to the iterator
        disp('This subject already had the step 1 files (Identification of bad channels)');
        contStep1 = contStep1 +1;
    end
    
    
    
    %% Step 2: Average reference (mean without bad channels)
    %Defines the path in which this step will (or should already) be saved
    iPathStep2 = fullfile(params.newPath, 'Preprocessing', 'Step2_AvgReference', iSubName, params.BIDSmodality);
    iNameStep2 = strcat('s2_', iSetName);
    
    %If the desired .set does not exist, and the user wants to run this step, run the analysis
    if ~exist(fullfile(iPathStep2, iNameStep2), 'file') && (ismember(2, step) || strcmp('all', step))
        disp('----------------Starting Step 2 (Re-referencing to average)-----------------');
        
        %First, check that the files for step0 and 1 exist
        if ~exist(fullfile(iPathStep0, iNameStep0), 'file')
            disp('WARNING: This subject does not have the files corresponding to step 0. Skipping to the next subject');
            continue
        end
        if ~exist(fullfile(iPathStep1, iNameStep1), 'file')
            disp('WARNING: This subject does not have the files corresponding to step 1. Skipping to the next subject');
            continue
        end
        
        %Re-references the .set
        [status, EEG] = f_step2Referencing(iPathStep0, iNameStep0, isReferenced, iPathStep1, iNameStep1, params.reref_REST);
        
        %If something went wrong, continue with the next subject
        if status == 0
            disp('ERROR: Unexpected mismatch between the badChannels.mat and the desired .set');
            continue;
        end
        
        %Add a new row to the .comments field, mentioning the parameters used for this step
        iComment = sprintf('Step 2: reref_REST = %s ', char(string(params.reref_REST)));
        EEG.comments = strvcat(EEG.comments, iComment);
        
        %If everything is okay, save the results
         if ~exist(iPathStep2, 'dir')
            mkdir(iPathStep2);
        end
        pop_saveset(EEG, 'filename', iNameStep2, 'filepath', iPathStep2);
        
        %Updates the parameters.txt with the parameters used
        statusUpdate = f_updateParametersTxtRS('reref_REST', params);
        if statusUpdate == 0
            disp('WARNING: Could not update the parameters.txt');
        end
        
        contStep2 = contStep2 +1;
        
        disp('----------------------------Step 2 completed--------------------------------');
    elseif (ismember(2, step) || strcmp('all', step))
        %If the file for step 2 already exists, let the user know and add to the iterator
        disp('This subject already had the step 2 files (Average reference)');
        contStep2 = contStep2 +1;
    end
    
    
    
    %% Step 3: Corrects artifacts in time (excluding bad channels)
    %Defines the path in which this step will (or should already) be saved
    iPathStep3 = fullfile(params.newPath, 'Preprocessing', 'Step3_CorrectArtifacts', iSubName, params.BIDSmodality);
    iNameStep3 = strcat('s3_', iSetName);
    
    %If the desired .set does not exist, and the user wants to run this step, run the analysis
    if ~exist(fullfile(iPathStep3, iNameStep3), 'file') && (ismember(3, step) || strcmp('all', step))
        disp('------------------Starting Step 3 (Correcting Artifacts)--------------------');
        
        %First, check that the files for step1 and 2 exist
        if ~exist(fullfile(iPathStep1, iNameStep1), 'file')
            disp('WARNING: This subject does not have the files corresponding to step 1. Skipping to the next subject');
            continue
        end
        if ~exist(fullfile(iPathStep2, iNameStep2), 'file')
            disp('WARNING: This subject does not have the files corresponding to step 2. Skipping to the next subject');
            continue
        end
              
        %Run the step of artifact correction in time
        [status, EEG] = f_step3CorrectArtifacts(iPathStep2, iNameStep2, iPathStep1, iNameStep1, params.burstCriterion, params.windowCriterion);
        
        %If something went wrong, continue with the next subject
        if status == 0
            disp('ERROR: Could not complete Step 3. Continuing with the next subject');
            continue;
        end
        
        %Add a new row to the .comments field, mentioning the parameters used for this step
        iComment = sprintf('Step 3: burstCriterion = %.1f ; windowCriterion = %.2f ', params.burstCriterion, params.windowCriterion);
        EEG.comments = strvcat(EEG.comments, iComment);
        
        %If everything is okay, save the results
        if ~exist(iPathStep3, 'dir')
            mkdir(iPathStep3);
        end
        pop_saveset(EEG, 'filename', iNameStep3, 'filepath', iPathStep3);
        %Save the figure as well
        saveas(gcf, fullfile(iPathStep3, strcat(iNameStep3(1:end-3), 'fig')));
        close;
        
        %Updates the parameters.txt with the parameters used
        statusUpdate0 = f_updateParametersTxtRS('burstCriterion', params);
        statusUpdate1 = f_updateParametersTxtRS('windowCriterion', params);
        if statusUpdate0 == 0 || statusUpdate1 == 0
            disp('WARNING: Could not update the parameters.txt');
        end
        
        contStep3 = contStep3 +1;
        
        disp('----------------------------Step 3 completed--------------------------------');
    
    elseif (ismember(3, step) || strcmp('all', step))
        %If the file for step 3 already exists, let the user know and add to the iterator
        disp('This subject already had the step 3 files (Artifact Correction)');
        contStep3 = contStep3 +1;
    end
    
    
    
    %% Step 4: Calculates the ICA for the good channels only
    %Defines the path in which this step will (or should already) be saved
    iPathStep4 = fullfile(params.newPath, 'Preprocessing', 'Step4_ICA', iSubName, params.BIDSmodality);
    iNameStep4 = strcat('s4_', iSetName);
    
    %If the desired .set does not exist, and the user wants to run this step, run the analysis
    if ~exist(fullfile(iPathStep4, iNameStep4), 'file') && (ismember(4, step) || strcmp('all', step))
        disp('---------------------Starting Step 4 (Calculating ICA)----------------------');
        
        %First, check that the files for step1 and step2 exist
        if ~exist(fullfile(iPathStep1, iNameStep1), 'file')
            disp('WARNING: This subject does not have the files corresponding to Step 1. Skipping to the next subject');
            continue
        end
        if ~exist(fullfile(iPathStep3, iNameStep3), 'file')
            disp('WARNING: This subject does not have the files corresponding to Step 3. Skipping to the next subject');
            continue
        end
        
        %Then, run the step of ICA calculation
        [status, EEG] = f_step4ICA(iPathStep3, iNameStep3, iPathStep1, iNameStep1);
        
        %If something went wrong, continue with the next subject
        if status == 0
            disp('ERROR: Unexpected mismatch between the badChannels.mat and the desired .set');
            continue;
        end
        
        %If everything is okay, save the results
        if ~exist(iPathStep4, 'dir')
            mkdir(iPathStep4);
        end
        pop_saveset(EEG, 'filename', iNameStep4, 'filepath', iPathStep4);
        contStep4 = contStep4 +1;
        
        disp('----------------------------Step 4 completed--------------------------------');
    
    elseif (ismember(4, step) || strcmp('all', step))
        %If the file for step 4 already exists, let the user know and add to the iterator
        disp('This subject already had the step 4 files (ICA computation)');
        contStep4 = contStep4 +1;
    end
    
    
    
    %% Step 5: Rejects noisy (heart and eyes or blinks) ICA components
    %Defines the path in which this step will (or should already) be saved
    iPathStep5 = fullfile(params.newPath, 'Preprocessing', 'Step5_RejectComponents', iSubName, params.BIDSmodality);
    iNameStep5 = strcat('s5_', iSetName);
    
    %If the desired .set does not exist, and the user wants to run this step, run the analysis
    if ~exist(fullfile(iPathStep5, iNameStep5), 'file') && (ismember(5, step) || strcmp('all', step))
        disp('------------------Starting Step 5 (Rejecting Components)--------------------');
        
        %First, check that the files for step4 exist
        if ~exist(fullfile(iPathStep4, iNameStep4), 'file')
            disp('WARNING: This subject does not have the files corresponding to step 4. Skipping to the next subject');
            continue
        end        
        
        %Creates the eyeCatch subject only once to improve speed
        if ~exist('eyeDetector', 'var')
            eyeDetector = eyeCatch;
        end
        
        %Then, run the step of ICA calculation
        [status, EEG, rejectedComponents] = f_step5RejectComponents(iPathStep4, iNameStep4, params.onlyBlinks, eyeDetector);
        
        %If something went wrong, continue with the next subject
        if status == 0
            disp('ERROR: The .set of the step 4 does not contain the ICA fields. Please make sure you are running the step4 properly');
            continue;
        end
        
        %Add a new row to the .comments field, mentioning the parameters used for this step
        iComment = sprintf('Step 5: onlyBlinks = %s ', char(string(params.onlyBlinks)));
        EEG.comments = strvcat(EEG.comments, iComment);
                        
        %If everything is okay, save the results
        if ~exist(iPathStep5, 'dir')
            mkdir(iPathStep5);
        end
        pop_saveset(EEG, 'filename', iNameStep5, 'filepath', iPathStep5);
        save(fullfile(iPathStep5, strcat('rejectedComponents_', iSubName, '.mat')), 'rejectedComponents');
        
        %Updates the parameters.txt with the parameters used
        statusUpdate = f_updateParametersTxtRS('onlyBlinks', params);
        if statusUpdate == 0
            disp('WARNING: Could not update the parameters.txt');
        end
        contStep5 = contStep5 +1;
        
        disp('----------------------------Step 5 completed--------------------------------');
    
    elseif (ismember(5, step) || strcmp('all', step))
        %If the file for step 5 already exists, let the user know and add to the iterator
        disp('This subject already had the step 5 files (Components rejection)');
        contStep5 = contStep5 +1;
    end
    
    
    
    %% Step 6: Interpolates the bad channels identified in Step 1
    %Defines the path in which this step will (or should already) be saved
    iPathStep6 = fullfile(params.newPath, 'Preprocessing', 'Step6_BadChanInterpolation', iSubName, params.BIDSmodality);
    iNameStep6 = strcat('s6_', iSetName);
    
    %If the desired .set does not exist, and the user wants to run this step, run the analysis
    if ~exist(fullfile(iPathStep6, iNameStep6), 'file') && (ismember(6, step) || strcmp('all', step))
        disp('---------------Starting Step 6 (Interpolating bad channels)-----------------');
        
        %First, check that the files for step5 and step2 exist
        if ~exist(fullfile(iPathStep5, iNameStep5), 'file')
            disp('WARNING: This subject does not have the files corresponding to Step 5. Skipping to the next subject');
            continue
        end
        if ~exist(fullfile(iPathStep1, iNameStep1), 'file')
            disp('WARNING: This subject does not have the files corresponding to Step 1. Skipping to the next subject');
            continue
        end
        
        %Then, run the step of Interpolation of bad channels
        [status, EEG] = f_step6InterpolateBadChans(iPathStep5, iNameStep5, iPathStep1, iNameStep1);
        
        %If something went wrong, continue with the next subject
        if status == 0
            disp('ERROR: Unexpected mismatch between the badChannels.mat and the desired .set');
            continue;
        end
        
        
        %If everything is okay, save the results
        if ~exist(iPathStep6, 'dir')
            mkdir(iPathStep6);
        end
        pop_saveset(EEG, 'filename', iNameStep6, 'filepath', iPathStep6);
        contStep6 = contStep6 +1;
        
        disp('----------------------------Step 6 completed--------------------------------');
    
    elseif (ismember(6, step) || strcmp('all', step))
        %If the file for step 6 already exists, let the user know and add to the iterator
        disp('This subject already had the step 6 files (Bad channel interpolation)');
        contStep6 = contStep6 +1;
    end
    
    
    
    %% End of the pre-processing for i-th subject
    fprintf('Pre processing finished for subject %s (%d/%d) \n', iSubName, i, nSubj);
end

%Prints the number of subjects available per step
fprintf('Number of subjects checked/saved for the database %s, over the BIDSmodality %s, and BIDStask %s IN THIS RUN: \n', databaseName, params.BIDSmodality, params.BIDStask);
fprintf('Original = %d \n', nSubj);
fprintf('Step 0 (Optional filtering and resampling) = %d / %d \n', contStep0, nSubj);
fprintf('Step 1 (Identification of bad channels) = %d / %d \n', contStep1, nSubj);
fprintf('Step 2 (Average reference) = %d / %d \n', contStep2, nSubj);
fprintf('Step 3 (Artifact correction) = %d / %d \n', contStep3, nSubj);
fprintf('Step 4 (ICA computation) = %d / %d \n', contStep4, nSubj);
fprintf('Step 5 (Components rejection) = %d / %d \n', contStep5, nSubj);
fprintf('Step 6 (Bad channel interpolation) = %d / %d \n', contStep6, nSubj);


%If it made it this far, the script was completed succesfully
status = 1;
finalStepPath = fullfile(params.newPath, 'Preprocessing', 'Step6_BadChanInterpolation');
preproParams = params;

end