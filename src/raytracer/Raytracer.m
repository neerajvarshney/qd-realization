function outputPath = Raytracer(paraCfgInput, nodeCfgInput)
% Inputs:
% RootFolderPath - it is the current location of the folder where the function is called from
% environmentFileName - it is the CAD file name
% switchRandomization - boolean to either randomly generates nodes and velocity or not
% mobilitySwitch -  is boolean to either have mobility or not
% totalNumberOfReflections - is the highest order of reflections to be computed
% switchQDGenerator - Switch to turn ON or OFF the Qausi dterministic module 1 = ON, 0 = OFF
% nodeLoc - 2d array which contains all node locations
% nodeVelocities - 2d array which contains all node velocities
% nodePolarization - 2d array which contains all node polarization
% nodeAntennaOrientation - 2d array which contains all node antenna orientation
% totalTimeDuration, n1 are for granularity in time domain. t is total period and n is the
% number of divisions of that time period
% mobilityType - This switch lets the user to decide the input to mobility
% 1 = Linear, 2 = input from File
% nodePosition - these are positions of nodes in a 2D array which are
% extracted from a file
% indoorSwitch - This boolean lets user say whether the given CAD file
% is indoor or outdorr. If indoor, then the value is 1 else the value is 0.
% generalizedScenario - This boolean lets user say whether a scenario
% conforms to a regular indoor or outdoor environment or it is a more
% general scenario.
% selectPlanesByDist - This is selection of planes/nodes by distance.
% r = 0 means that there is no limitation.
% referencePoint - Reference point is the center of limiting sphere
%
% Outputs:
% N/A


% -------------Software Disclaimer---------------
%
% NIST-developed software is provided by NIST as a public service. You may use, copy
% and distribute copies of the software in any medium, provided that you keep intact this
% entire notice. You may improve, modify and create derivative works of the software or
% any portion of the software, and you may copy and distribute such modifications or
% works. Modified works should carry a notice stating that you changed the software
% and should note the date and nature of any such change. Please explicitly
% acknowledge the National Institute of Standards and Technology as the source of the
% software.
%
% NIST-developed software is expressly provided "AS IS." NIST MAKES NO
% WARRANTY OF ANY KIND, EXPRESS, IMPLIED, IN FACT OR ARISING BY
% OPERATION OF LAW, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
% WARRANTY OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
% NON-INFRINGEMENT AND DATA ACCURACY. NIST NEITHER REPRESENTS
% NOR WARRANTS THAT THE OPERATION OF THE SOFTWARE WILL BE
% UNINTERRUPTED OR ERROR-FREE, OR THAT ANY DEFECTS WILL BE
% CORRECTED. NIST DOES NOT WARRANT OR MAKE ANY REPRESENTATIONS
% REGARDING THE USE OF THE SOFTWARE OR THE RESULTS THEREOF,
% INCLUDING BUT NOT LIMITED TO THE CORRECTNESS, ACCURACY,
% RELIABILITY, OR USEFULNESS OF THE SOFTWARE.
%
% You are solely responsible for determining the appropriateness of using
% anddistributing the software and you assume all risks associated with its use, including
% but not limited to the risks and costs of program errors, compliance with applicable
% laws, damage to or loss of data, programs or equipment, and the unavailability or
% interruption of operation. This software is not intended to be used in any situation
% where a failure could cause risk of injury or damage to property. The software
% developed by NIST employees is not subject to copyright protection within the United
% States.
%
% Modified by: Mattia Lecci <leccimat@dei.unipd.it>, Refactored code


%% Input Parameters Management
mobilitySwitch = paraCfgInput.mobilitySwitch;
mobilityType = paraCfgInput.mobilityType;
numberOfNodes = paraCfgInput.numberOfNodes;
numberOfTimeDivisions = paraCfgInput.numberOfTimeDivisions;
switchRandomization = paraCfgInput.switchRandomization;

nodeLoc = nodeCfgInput.nodeLoc;
nodeVelocities = nodeCfgInput.nodeVelocities;

% Input checking
if paraCfgInput.switchQDGenerator &&...
        paraCfgInput.carrierFrequency ~= 60e9
    warning(['Please, note that diffuse scattering model is only ',...
        'valid for fc=60 GHz'])
end

% List of paths
inputPath = strcat(paraCfgInput.inputScenarioName, '/Input');
outputPath = strcat(paraCfgInput.inputScenarioName, '/Output');

ns3Path = strcat(outputPath, '/Ns3');
qdFilesPath = strcat(ns3Path, '/QdFiles');

if paraCfgInput.switchSaveVisualizerFiles
    visualizerPath = strcat(outputPath, '/Visualizer');
    
    nodePositionsPath = strcat(visualizerPath, '/NodePositions');
    roomCoordinatesPath = strcat(visualizerPath, '/RoomCoordinates');
    mpcCoordinatesPath = strcat(visualizerPath, '/MpcCoordinates');
end

% Subfolders creation
if ~isfolder(qdFilesPath)
    mkdir(qdFilesPath)
end

if paraCfgInput.switchSaveVisualizerFiles
    
    if ~isfolder(nodePositionsPath)
        mkdir(nodePositionsPath)
    end
    if ~isfolder(roomCoordinatesPath)
        mkdir(roomCoordinatesPath)
    end
    if ~isfolder(mpcCoordinatesPath)
        mkdir(mpcCoordinatesPath)
    end
    
end

% Init output files
fids = getQdFilesIds(qdFilesPath,numberOfNodes);


Tx = nodeLoc(1,:);
Rx = nodeLoc(2,:);
vtx = nodeVelocities(1,:);
vrx = nodeVelocities(2,:);

MaterialLibrary = importMaterialLibrary('raytracer/Material_library.txt');

% Extracting CAD file and storing in an XMl file, CADFile.xml
[CADop, switchMaterial, visibilityMatrix, minDistMatrix] = getCadOutput(...
    paraCfgInput.environmentFileName, inputPath, MaterialLibrary,...
    paraCfgInput.referencePoint, paraCfgInput.selectPlanesByDist,...
    paraCfgInput.indoorSwitch);

if paraCfgInput.switchSaveVisualizerFiles
    % Save output file with room coordinates for visualization
    RoomCoordinates = CADop(:, 1:9);
    csvwrite(sprintf('%s/RoomCoordinates.csv',roomCoordinatesPath),...
        RoomCoordinates);
end

% Randomization
%if number of nodes is greater than 1 or switch_randomization is set to 1,
%the program generates nodes randomly. If one has more than 2 nodes but
%know the exact locations of nodes, then disable this if statement and
%replace node and node_v with the values of node positions and node
%velocities repsectively

TxInitial = Tx;
RxInitial = Rx;
% t - total time period, n - number of divisions
if mobilitySwitch
    timeDivisionValue = paraCfgInput.totalTimeDuration / paraCfgInput.numberOfTimeDivisions;
else
    numberOfTimeDivisions = 0;
    timeDivisionValue = 0;
end

% Finite difference method to simulate mobility. x=x0 + v*dt.
% This method ensures the next position wouldnt collide with any of the
% planes. If that occurs then the velocities are simply reversed (not
% reflected). At every time step the positions of all nodes are updated

for iterateTimeDivision = 0:numberOfTimeDivisions
    if mobilityType == 1
        if numberOfNodes == 2
            [nodeLoc,Tx,Rx,vtx, vrx, nodeVelocities] = LinearMobility...
                (numberOfNodes, switchRandomization, ...
                iterateTimeDivision, nodeLoc, nodeVelocities, vtx,...
                vrx,TxInitial, RxInitial, timeDivisionValue,...
                CADop, Tx, Rx);
        else
            [nodeLoc,Tx,Rx,vtx, vrx, nodeVelocities] = LinearMobility...
                (numberOfNodes, switchRandomization,...
                iterateTimeDivision, nodeLoc, nodeVelocities,...
                [], [], TxInitial, RxInitial, timeDivisionValue, ...
                CADop, Tx, Rx);
        end
        
    elseif mobilityType == 2
        [nodeLoc, nodeVelocities] = NodeExtractor...
            (numberOfNodes,  switchRandomization, ...
            iterateTimeDivision, nodeLoc, nodeVelocities,...
            nodeCfgInput.nodePosition, timeDivisionValue);
    end
    
    if paraCfgInput.switchSaveVisualizerFiles && mobilitySwitch >=0
        csvwrite(sprintf('%s/NodePositionsTrc%d.csv',...
            nodePositionsPath, iterateTimeDivision),...
            nodeLoc);
    end
    
    % Iterates through all the nodes
    for iterateTx = 1:numberOfNodes
        for iterateRx = iterateTx+1:numberOfNodes
            
            if numberOfNodes >= 2 || switchRandomization
                Tx = nodeLoc(iterateTx, :);
                Rx = nodeLoc(iterateRx, :);
                
                vtx = nodeVelocities(iterateTx, :);
                vrx = nodeVelocities(iterateRx, :);
            end
                
            % LOS Path generation
            [output, rayVertices] = computeLosOutput(Rx, Tx, vrx, vtx,...
                CADop, paraCfgInput.carrierFrequency,...
                paraCfgInput.minAbsolutePathGainThreshold);
            
            if ~isempty(output)
                % if LoS path exists, it is currently the only existing one
                currentMaxPathGain = output(9);
            else
                % else, reset
                currentMaxPathGain = -Inf;
            end
            
            if paraCfgInput.switchSaveVisualizerFiles &&...
                    ~isempty(output) &&...
                    iterateTx < iterateRx
                % Save MPC LoS file if ray is present
                csvwrite(sprintf('%s/MpcTx%dRx%dRefl%dTrc%d.csv',...
                    mpcCoordinatesPath, iterateTx-1, iterateRx-1, 0, iterateTimeDivision),...
                    rayVertices); 

            end
                
            % Higher order reflections (Non LOS)
            triangReflIdxList = [];
            for iterateOrderOfReflection = 1:paraCfgInput.totalNumberOfReflections
                triangReflIdxList = generateReflectionList(...
                    triangReflIdxList, CADop, visibilityMatrix);
                
                if mobilitySwitch == -1 % ??
                    vtx = [0, 0, 0];
                    vrx = vtx;
                end
                
                [outputTmp, rayVertices, currentMaxPathGain] = mymultipath(...
                    Rx, Tx, vrx, vtx, triangReflIdxList, CADop,...
                    visibilityMatrix, MaterialLibrary,...
                    paraCfgInput.switchQDGenerator, switchMaterial,...
                    paraCfgInput.carrierFrequency,...
                    paraCfgInput.minAbsolutePathGainThreshold,...
                    paraCfgInput.minRelativePathGainThreshold, currentMaxPathGain);
                        
                if paraCfgInput.switchSaveVisualizerFiles &&...
                        iterateTx < iterateRx &&...
                        size(rayVertices,1) ~= 0
                    
                    csvwrite(sprintf('%s/MpcTx%dRx%dRefl%dTrc%d.csv',...
                        mpcCoordinatesPath, iterateTx-1, iterateRx-1,...
                        iterateOrderOfReflection, iterateTimeDivision),...
                        rayVertices(:, 2:end));
                end
                
                if size(output) > 0
                    output = [output; outputTmp];
                elseif size(outputTmp) > 0
                    output = outputTmp;
                end
                                     
            end
            
            % Clean up reflections with path gain lower than
            % minRelativePathGainThreshold to avoid external simulator from
            % computing useless additional steering vectors
            % In fact, especially for the NLoS case, there is no guarantee
            % that the strongest path will be found first
            if ~isempty(output)
                removeIdx = output(:,9) - currentMaxPathGain < paraCfgInput.minRelativePathGainThreshold;
                output(removeIdx, :) = [];
            end
            
            % The ouput from previous iterations is stored in files
            % whose names are TxiRxj.txt. i,j is the link
            % between ith node as Tx and jth as Rx.
            writeQdFileOutput(output, fids(iterateTx,iterateRx),...
                paraCfgInput.qdFilesFloatPrecision);
            writeQdFileOutput(reverseOutputTxRx(output), fids(iterateRx,iterateTx),...
                paraCfgInput.qdFilesFloatPrecision);

        end
    end
    
end

closeQdFilesIds(fids);

end