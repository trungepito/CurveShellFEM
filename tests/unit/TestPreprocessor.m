classdef TestPreprocessor < matlab.unittest.TestCase
    % TESTPREPROCESSOR Unit tests for FEM_Preprocessor_v2
    
    properties
        Pre
    end
    
    methods(TestMethodSetup)
        function setup(testCase)
            testCase.Pre = FEM_Preprocessor_v2(200e9, 0.3, 0.01);
        end
    end
    
    methods(Test)
        function testInitialization(testCase)
            testCase.verifyEmpty(testCase.Pre.Mesh.Nodes);
            testCase.verifyTrue(istable(testCase.Pre.BCs));
            testCase.verifyTrue(istable(testCase.Pre.Loads));
        end
        
        function testAddBC(testCase)
            testCase.Pre.addBC(1, 1, 0.5, 'TestFixed');
            testCase.verifyEqual(height(testCase.Pre.BCs), 1);
            testCase.verifyEqual(testCase.Pre.BCs.Node(1), 1);
            testCase.verifyEqual(testCase.Pre.BCs.DOF(1), 1);
            testCase.verifyEqual(testCase.Pre.BCs.Value(1), 0.5);
            testCase.verifyEqual(testCase.Pre.BCs.Tag{1}, 'TestFixed');
        end
        
        function testAddLoad(testCase)
            testCase.Pre.addNodalLoad(10, 3, -1000, 'TestLoad');
            testCase.verifyEqual(height(testCase.Pre.Loads), 1);
            testCase.verifyEqual(testCase.Pre.Loads.Node(1), 10);
            testCase.verifyEqual(testCase.Pre.Loads.DOF(1), 3);
            testCase.verifyEqual(testCase.Pre.Loads.Value(1), -1000);
        end
        
        function testCreatePlate(testCase)
            % Test basic plate generation
            origin = [0, 0, 0];
            testCase.Pre.createPlate(origin, 1.0, 1.0);
            testCase.Pre.meshAllPatches(1, 1);
            
            % For a single 8-node element: 8 nodes, 1 element
            testCase.verifyEqual(size(testCase.Pre.Mesh.Nodes, 1), 8);
            testCase.verifyEqual(size(testCase.Pre.Mesh.Elements, 1), 1);
        end
        
        function testFusingNodes(testCase)
            % Create two overlapping elements
            testCase.Pre.Mesh.Nodes = [0 0 0; 1 0 0; 1 1 0; 0 1 0; 0.5 0 0; 1 0.5 0; 0.5 1 0; 0 0.5 0]; % El 1
            testCase.Pre.Mesh.Nodes = [testCase.Pre.Mesh.Nodes; ...
                                      0 0 0; 1 0 0; 1 1 0; 0 1 0; 0.5 0 0; 1 0.5 0; 0.5 1 0; 0 0.5 0]; % Duplicates
            testCase.Pre.Mesh.Elements = [1:8; 9:16];
            
            initialCount = size(testCase.Pre.Mesh.Nodes, 1);
            testCase.Pre.fuseNodes(1e-5);
            finalCount = size(testCase.Pre.Mesh.Nodes, 1);
            
            testCase.verifyEqual(initialCount, 16);
            testCase.verifyEqual(finalCount, 8);
            testCase.verifyEqual(max(testCase.Pre.Mesh.Elements(:)), 8);
        end
    end
end
