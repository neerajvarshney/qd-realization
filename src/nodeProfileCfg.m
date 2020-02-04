function [paraCfg, nodeCfg] = nodeProfileCfg(paraCfg)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

scenarioNameStr = paraCfg.inputScenarioName;
% Input Parameters to be Updated
mobilitySwitch = paraCfg.mobilitySwitch;
mobilityType = paraCfg.mobilityType;
numberOfNodes = paraCfg.numberOfNodes;
numberOfTimeDivisions = paraCfg.numberOfTimeDivisions;
switchRandomization = paraCfg.switchRandomization;

% List of paths
inputPath = fullfile(scenarioNameStr, 'Input');
nodesPositionPath = fullfile(scenarioNameStr, 'Output/Ns3/NodesPosition');

%% Code
nodePosition = [];

%% Random generation of node positions
if switchRandomization == 1
    xCoordinateRandomizer = rand * 8 + 1;
    yCoordinateRandomizer = rand * 17 + 1;
    zCoordinateRandomizer = 2.5;
    Tx = [xCoordinateRandomizer, yCoordinateRandomizer, zCoordinateRandomizer];
    
    xCoordinateRandomizer = rand * 8 + 1;
    yCoordinateRandomizer = rand * 17 + 1;
    zCoordinateRandomizer = 1.6;
    Rx = [xCoordinateRandomizer, yCoordinateRandomizer, zCoordinateRandomizer];
    
    if mobilityType ~= 1
        mobilityType = 1;
        warning('Changing mobilityType to %d', mobilityType)
    end
end

%% Extracting data from nodes.dat and nodeVelocities.dat file.
% nodes.dat file contains nodes locations and nodeVelocities contains their
% velocities
if switchRandomization == 0
    try
        nodeLoc = csvread(fullfile(inputPath, 'nodes.dat'));
        nodeVelocities = csvread(fullfile(inputPath, 'nodeVelocities.dat'));
    catch
        switchRandomization = 1;
        warning(['Unable to read nodes.dat or nodeVelocities.dat. ',...
            'Changing switchRandomization to %d'], switchRandomization)
    end
    
    if size(nodeLoc,1) ~= size(nodeVelocities,1) && mobilitySwitch == 1
        error(['nodes.dat and nodeVelocities.dat do not have same number ',...
            'of rows. Please check the input files in the Input folder.'])
    end
    
    if ~isempty(numberOfNodes) && numberOfNodes ~= size(nodeLoc, 1)
        warning(['"numberOfNodes" parameter does not match the number of ',...
            'nodes given in file. The "numberOfNodes" is adjusted to ',...
            'the number of nodes given in file (%d)'], size(nodeLoc, 1));
    end
    numberOfNodes = size(nodeLoc, 1);
    
    if mobilitySwitch == 1
        nodeVelocitiesTemp = nodeVelocities;
        clear nodeVelocities;
        nodeVelocities = nodeVelocitiesTemp(1:numberOfNodes, :);
    else
        clear nodeVelocities;
        nodeVelocities = zeros(numberOfNodes, 3);
    end
    
    if mobilityType == 2
        listing = dir(fullfile(scenarioNameStr, 'Input'));
        
        countListing = 0;
        for iterateSizeListing = 1:size(listing, 1)
            ln = listing(iterateSizeListing).name;
            
            for iterateNumberOfNodes = 1:numberOfNodes
                if strcmp(ln, sprintf('NodePosition%d.dat', iterateNumberOfNodes))
                    nodePositionTemp = load(fullfile(inputPath, ln));
                    
                    try
                        nodePosition(:, :, iterateNumberOfNodes) = nodePositionTemp;
                        countListing = countListing + 1;
                    catch
                        mobilityType = 1;
                        warning('Node Position input incorrect. Changing mobilityType to 1');
                    end
                    
                end
            end
        end
        
        if mobilityType == 2 && countListing < numberOfNodes
            warning(['Node Position input incorrect. Linear mobility',...
                'model is chosen']);
            mobilityType = 1;
        elseif mobilityType == 2 && countListing == numberOfNodes
            % Cannot compute last velocity, so stop one iteration earlier
            if numberOfTimeDivisions ~= size(nodePosition, 1) - 1
                numberOfTimeDivisions = size(nodePosition, 1) - 1;
                warning('Changing numberOfTimeDivisions to %d', numberOfTimeDivisions)
            end
        end
        
    end
end

if mobilitySwitch == 1
    nodeVelocitiesTemp = nodeVelocities;
    clear nodeVelocities;
    nodeVelocities = nodeVelocitiesTemp(1:numberOfNodes, :);
else
    clear nodeVelocities;
    nodeVelocities = zeros(numberOfNodes, 3);
    
    if numberOfTimeDivisions ~= 1
        numberOfTimeDivisions = 1;
        warning('Changing numberOfTimeDivisions to %d', numberOfTimeDivisions)
    end
    
    if paraCfg.totalTimeDuration ~= 0
        paraCfg.totalTimeDuration = 0;
        warning('Changing totalTimeDuration to %d', paraCfg.totalTimeDuration)
    end
end

iterateNumberOfNodes = 1;
%% This part of code generates other parameters of
nodeAntennaOrientation = zeros(numberOfNodes, 3, 3);
nodePolarization = zeros(iterateNumberOfNodes, 2);

while iterateNumberOfNodes <= numberOfNodes
    nodeAntennaOrientation(iterateNumberOfNodes, :, :) = [1, 0, 0; 0, 1, 0; 0, 0, 1];
    nodePolarization(iterateNumberOfNodes, :) = [1, 0];
    
    if switchRandomization == 1 && iterateNumberOfNodes > 0
        xCoordinateRandomizer = rand * 8 + 1;
        yCoordinateRandomizer = rand * 17 + 1;
        zCoordinateRandomizer = 1.6;
        nodeLoc(iterateNumberOfNodes, :) =...
            [xCoordinateRandomizer, yCoordinateRandomizer, zCoordinateRandomizer];
        
        xCoordinateRandomizer = rand * 0.7;
        yCoordinateRandomizer = sqrt((0.7^2) - (xCoordinateRandomizer^2));
        zCoordinateRandomizer = 0;
        nodeVelocities(iterateNumberOfNodes, :) =...
            [xCoordinateRandomizer, yCoordinateRandomizer, zCoordinateRandomizer];
    end
    
    iterateNumberOfNodes = iterateNumberOfNodes + 1;
end

if switchRandomization ~=0
    switchRandomization = 0;
    warning('Changing switchRandomization to %d', switchRandomization)
end

% Check Temp Output Folder
rmdirStatus = rmdir(fullfile(scenarioNameStr, 'Output'), 's');

mkdir(fullfile(scenarioNameStr, 'Output'));
mkdir(fullfile(scenarioNameStr, 'Output/Ns3'));
mkdir(fullfile(scenarioNameStr, 'Output/Visualizer'));

if ~isfolder(nodesPositionPath)
    mkdir(nodesPositionPath)
end

csvwrite(fullfile(nodesPositionPath, 'NodesPosition.csv'), nodeLoc);

warning('OFF', 'MATLAB:table:ModifiedAndSavedVarnames')

paraCfg.mobilityType = mobilityType;
paraCfg.numberOfNodes = numberOfNodes;
paraCfg.numberOfTimeDivisions = numberOfTimeDivisions;
paraCfg.switchRandomization = switchRandomization;

nodeCfg.nodeLoc = nodeLoc;
nodeCfg.nodeAntennaOrientation = nodeAntennaOrientation;
nodeCfg.nodePolarization = nodePolarization;
nodeCfg.nodePosition = nodePosition;
nodeCfg.nodeVelocities = nodeVelocities;

end
