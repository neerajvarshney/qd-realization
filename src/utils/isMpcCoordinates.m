function b = isMpcCoordinates(path)
%ISMPCCOORDINATES Function that checks whether the given path matches with
% the expected MPC Coordinates output file position (as given by the
% documentation). This allows to safely read the file later.
%
% INPUTS:
% - path: file path. This could be either and absolute path, or a relative
% path, starting at least from the Output/ folder.
%
% SEE ALSO: READMPCCOORDINATES


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

[remainingPath, fileName, extension] = fileparts(path);
b = ~isempty(regexp([fileName, extension],...
    'MpcTx[\d]+Rx[\d]+Refl[\d]+Trc[\d]+.csv',...
    'once'));

[remainingPath, mpCoordinatesFolder] = fileparts(remainingPath);
b = b && strcmp(mpCoordinatesFolder, 'MpcCoordinates');

[remainingPath, visualizerFolder] = fileparts(remainingPath);
b = b && strcmp(visualizerFolder, 'Visualizer');

[~, outputFolder] = fileparts(remainingPath);
b = b && strcmp(outputFolder, 'Output');

end