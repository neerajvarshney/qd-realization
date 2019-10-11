% Copyright (c) 2019, University of Padova, Department of Information
% Engineering, SIGNET lab.
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
%
%    http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.

clear
close all
clc

addpath('raytracer', 'utils')

% specify node ID to select file to be loaded
txId = 0;
rxId = 1;

scenario = 'L-Room';
scenarioPath = fullfile('statsScenarios',scenario);

% save every execution in a different folder
currFolder = fullfile(scenarioPath,datestr(now,'mm-dd-yyyy HH-MM-SS'));

%% config parameters
inputPath = fullfile(currFolder,'Input');
mkdir(inputPath)
cfgParams.numberOfTimeDivisions = 200;
genParameterCfg(cfgParams,inputPath);

%% create TX-RX grid
% specify the TX position
txPos = [0.2,3,2.5]; % the transmitter position is fixed
visualize=true;
randomSampling = true;
createTxRxGrid(currFolder,randomSampling,txPos,visualize);

%% execute the ray-tracer
generateRayTracerOutFiles(currFolder)

%% extract statistics
outputPath = fullfile(currFolder,'Output','Ns3','QdFiles',sprintf('Tx%dRx%d.txt',txId,rxId));
output = readQdFile(outputPath);

feature = 'pathGain'; % specify the metric to observe for the statistics
if ~isfield(output,feature)
    error('feature must be a field of Tx%sRx%s.txt',txId,rxId);
end

currFeature = extractfield(output,feature);

figure()
ecdf(currFeature)
xlabel('$x=$ Path Gain')
ylabel('$F(x)$')
% title('Path Gain distribution in a rectangular room. $N_{refl}=2$')
 
figure()
histogram(currFeature)
xlabel('Path Gain')
ylabel('Count')
% title('Path Gain distribution in a rectangular room. $N_{refl}=2$')


function []=generateRayTracerOutFiles(currPath)
    %% Initialization 
    rootFolderPath = pwd;
    fprintf('-------- NIST/CTL QD mmWave Channel Model --------\n');
    fprintf('Current root folder:\n\t%s\n',rootFolderPath);
    [path,folderName] = fileparts(rootFolderPath);
    if strcmp(folderName, 'src')
        fprintf('Start to run.\n');
    else
        error('The root folder should be ''src''');
    end

    %% Input
    endout=regexp(currPath,filesep,'split');
    scenarioNameStr = endout{2};
    sprintf('Use scenario: %s.\n',scenarioNameStr);

    % Check Input Scenario File
    scenarioInputPath = fullfile(currPath,'/Input');

    % Input System Parameters
    paraCfg = parameterCfg(currPath);
    % Input Node related parameters
    [paraCfg, nodeCfg] = nodeProfileCfg(paraCfg);

    % To collect the statistics, we need these two switches
    paraCfg.switchSaveVisualizerFiles = 1;
    paraCfg.mobilitySwitch = 1;
    % Run raytracing function and generate outputs
    outputPath = Raytracer_collectStats(paraCfg, nodeCfg);

    fprintf('Save output data to:\n%s\n',outputPath);
    fprintf('--------- Simulation Complete ----------\n');
end