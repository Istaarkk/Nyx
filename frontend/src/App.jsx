import React, { useState, useEffect } from 'react';
import { QueryClient, QueryClientProvider, useQuery, useMutation } from 'react-query';
import axios from 'axios';

// Configuration de l'API
const API_URL = 'http://localhost:8000';
const queryClient = new QueryClient();

// Composant principal
function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <div className="min-h-screen bg-gray-100">
        <header className="bg-slate-800 text-white p-4 shadow-md">
          <h1 className="text-2xl font-bold">Plateforme d'Analyse de Malwares</h1>
        </header>
        <main className="container mx-auto p-4">
          <AnalysisDashboard />
        </main>
      </div>
    </QueryClientProvider>
  );
}

// Tableau des analyses
function AnalysisDashboard() {
  const [selectedFile, setSelectedFile] = useState(null);
  
  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div className="md:col-span-2">
        <div className="bg-white p-4 rounded shadow mb-4">
          <h2 className="text-xl font-semibold mb-4">Nouvelle analyse</h2>
          <FileUploader />
        </div>
        <div className="bg-white p-4 rounded shadow mb-4">
          <StartInteractiveButton />
        </div>
        <div className="bg-white p-4 rounded shadow">
          <h2 className="text-xl font-semibold mb-4">Analyses récentes</h2>
          <AnalysesList onSelectFile={setSelectedFile} />
        </div>
      </div>
      <div className="md:col-span-1">
        <div className="bg-white p-4 rounded shadow sticky top-4">
          <h2 className="text-xl font-semibold mb-4">Détails</h2>
          {selectedFile ? (
            <AnalysisDetails fileId={selectedFile} />
          ) : (
            <p className="text-gray-500">Sélectionnez une analyse pour voir les détails.</p>
          )}
        </div>
      </div>
    </div>
  );
}

// Composant d'upload de fichier
function FileUploader() {
  const [file, setFile] = useState(null);
  
  const uploadMutation = useMutation(
    (formData) => axios.post(`${API_URL}/upload`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    }),
    {
      onSuccess: () => {
        queryClient.invalidateQueries('analyses');
        setFile(null);
      }
    }
  );
  
  const handleFileChange = (e) => {
    if (e.target.files.length > 0) {
      setFile(e.target.files[0]);
    }
  };
  
  const handleSubmit = (e) => {
    e.preventDefault();
    if (!file) return;
    
    const formData = new FormData();
    formData.append('file', file);
    
    uploadMutation.mutate(formData);
  };
  
  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="border-2 border-dashed border-gray-300 rounded p-4 text-center">
        <input
          type="file"
          onChange={handleFileChange}
          className="hidden"
          id="fileInput"
        />
        <label
          htmlFor="fileInput"
          className="cursor-pointer text-blue-600 hover:text-blue-800"
        >
          {file ? file.name : "Sélectionner un fichier à analyser"}
        </label>
      </div>
      
      <button
        type="submit"
        disabled={!file || uploadMutation.isLoading}
        className={`w-full py-2 px-4 rounded ${
          !file || uploadMutation.isLoading
            ? 'bg-gray-300 cursor-not-allowed'
            : 'bg-blue-600 hover:bg-blue-700 text-white'
        }`}
      >
        {uploadMutation.isLoading ? 'Envoi en cours...' : 'Lancer l\'analyse'}
      </button>
      
      {uploadMutation.isError && (
        <div className="text-red-600 text-sm mt-2">
          Erreur: {uploadMutation.error.message}
        </div>
      )}
    </form>
  );
}

// Liste des analyses
function AnalysesList({ onSelectFile }) {
  const { data, isLoading, isError } = useQuery('analyses', 
    () => axios.get(`${API_URL}/files`).then(res => res.data),
    { refetchInterval: 5000 } // Rafraîchir toutes les 5 secondes
  );
  
  if (isLoading) return <p>Chargement des analyses...</p>;
  if (isError) return <p className="text-red-600">Erreur: Impossible de charger les analyses</p>;
  
  const getStatusColor = (status) => {
    switch (status) {
      case 'completed': return 'bg-green-100 text-green-800';
      case 'failed': return 'bg-red-100 text-red-800';
      case 'running': return 'bg-blue-100 text-blue-800';
      default: return 'bg-yellow-100 text-yellow-800';
    }
  };
  
  return (
    <div className="overflow-x-auto">
      <table className="min-w-full">
        <thead className="bg-gray-50">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Fichier
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Statut
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Date
            </th>
          </tr>
        </thead>
        <tbody className="bg-white divide-y divide-gray-200">
          {data.length === 0 ? (
            <tr>
              <td colSpan="3" className="px-6 py-4 text-center text-gray-500">
                Aucune analyse trouvée
              </td>
            </tr>
          ) : (
            data.map((analysis) => (
              <tr 
                key={analysis.id}
                onClick={() => onSelectFile(analysis.id)}
                className="cursor-pointer hover:bg-gray-50"
              >
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="text-sm font-medium text-gray-900">{analysis.filename}</div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${getStatusColor(analysis.status)}`}>
                    {analysis.status}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {new Date(analysis.upload_time).toLocaleString()}
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
}

// Détails d'une analyse
function AnalysisDetails({ fileId }) {
  const { data: analysis, isLoading: loadingAnalysis } = useQuery(
    ['analysis', fileId],
    () => axios.get(`${API_URL}/files/${fileId}`).then(res => res.data)
  );
  
  const { data: results, isLoading: loadingResults } = useQuery(
    ['results', fileId],
    () => axios.get(`${API_URL}/files/${fileId}/results`).then(res => res.data),
    { enabled: analysis?.status === 'completed' && analysis?.analysis_type !== 'interactive' }
  );
  
  const restartMutation = useMutation(
    () => axios.post(`${API_URL}/files/${fileId}/restart`),
    {
      onSuccess: () => {
        queryClient.invalidateQueries('analyses');
        queryClient.invalidateQueries(['analysis', fileId]);
      }
    }
  );
  
  if (loadingAnalysis) return <p>Chargement des détails...</p>;
  if (!analysis) return <p>Aucune analyse trouvée avec cet ID</p>;
  
  // Si c'est une session interactive, afficher l'interface du terminal
  if (analysis?.analysis_type === 'interactive') {
    return (
      <div className="space-y-4">
        <div>
          <h3 className="font-bold text-lg">{analysis.filename}</h3>
          <div className="mt-2 text-sm text-gray-500">
            <p><strong>ID:</strong> {analysis.id}</p>
            <p><strong>Type:</strong> Session interactive</p>
            <p><strong>Statut:</strong> {analysis.status}</p>
            <p><strong>Démarré le:</strong> {new Date(analysis.upload_time).toLocaleString()}</p>
          </div>
        </div>
        
        <TerminalSession fileId={fileId} />
      </div>
    );
  }
  
  return (
    <div className="space-y-4">
      <div>
        <h3 className="font-bold text-lg">{analysis.filename}</h3>
        <div className="mt-2 text-sm text-gray-500">
          <p><strong>ID:</strong> {analysis.id}</p>
          <p><strong>Statut:</strong> {analysis.status}</p>
          <p><strong>Date d'upload:</strong> {new Date(analysis.upload_time).toLocaleString()}</p>
          {analysis.completion_time && (
            <p><strong>Date de complétion:</strong> {new Date(analysis.completion_time).toLocaleString()}</p>
          )}
          {analysis.file_hash && (
            <p><strong>SHA256:</strong> {analysis.file_hash}</p>
          )}
        </div>
      </div>
      
      {analysis.status === 'failed' && (
        <div className="bg-red-100 p-3 rounded text-red-800 text-sm">
          L'analyse a échoué. Vous pouvez la relancer.
          <button
            onClick={() => restartMutation.mutate()}
            className="ml-2 bg-red-500 hover:bg-red-600 text-white px-2 py-1 rounded text-xs"
          >
            Relancer
          </button>
        </div>
      )}
      
      {analysis.status === 'pending' && (
        <div className="bg-yellow-100 p-3 rounded text-yellow-800 text-sm">
          En attente de traitement...
        </div>
      )}
      
      {analysis.status === 'running' && (
        <div className="bg-blue-100 p-3 rounded text-blue-800 text-sm">
          Analyse en cours...
        </div>
      )}
      
      {analysis.status === 'completed' && (
        <div className="space-y-4">
          <div className="flex space-x-2">
            <button
              onClick={() => document.getElementById('results').scrollIntoView({ behavior: 'smooth' })}
              className="bg-blue-100 hover:bg-blue-200 text-blue-800 px-3 py-1 rounded text-sm"
            >
              Résultats
            </button>
            <button
              onClick={() => document.getElementById('assembly').scrollIntoView({ behavior: 'smooth' })}
              className="bg-green-100 hover:bg-green-200 text-green-800 px-3 py-1 rounded text-sm"
            >
              Code Assembleur
            </button>
          </div>
          
          <div id="results">
            <h4 className="font-semibold text-md mb-2">Résultats</h4>
            {loadingResults ? (
              <p>Chargement des résultats...</p>
            ) : results ? (
              <ResultsView results={results} />
            ) : (
              <p>Aucun résultat disponible</p>
            )}
          </div>
          
          <div id="assembly" className="mt-6">
            <h4 className="font-semibold text-md mb-2">Code Assembleur</h4>
            <AssemblyView fileId={fileId} />
          </div>
        </div>
      )}
    </div>
  );
}

// Composant pour afficher le code assembleur
function AssemblyView({ fileId }) {
  const [assembly, setAssembly] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  useEffect(() => {
    setLoading(true);
    axios.get(`${API_URL}/files/${fileId}/assembly`)
      .then(response => {
        setAssembly(response.data);
        setLoading(false);
      })
      .catch(err => {
        console.error("Erreur lors du chargement du code assembleur:", err);
        setError(err.response?.data?.detail || err.message);
        setLoading(false);
      });
  }, [fileId]);
  
  if (loading) return <p>Chargement du code assembleur...</p>;
  if (error) return <p className="text-red-600">Erreur: {error}</p>;
  if (!assembly) return <p>Aucun code assembleur disponible</p>;
  
  return (
    <div className="space-y-2">
      <div className="bg-gray-100 p-2 rounded">
        <p><strong>Type de fichier détecté:</strong> {assembly.file_type}</p>
      </div>
      <div className="bg-gray-800 p-4 rounded text-white overflow-auto max-h-96">
        <pre className="text-xs font-mono whitespace-pre-wrap">{assembly.assembly_code}</pre>
      </div>
    </div>
  );
}

// Affichage des résultats de l'analyse
function ResultsView({ results }) {
  return (
    <div className="mt-2 space-y-4">
      <div>
        <h5 className="font-medium text-sm">Métadonnées</h5>
        <pre className="bg-gray-100 p-2 rounded text-xs overflow-auto mt-1">
          {JSON.stringify(results.metadata, null, 2)}
        </pre>
      </div>
      
      {results.tools && Object.keys(results.tools).map(tool => (
        <div key={tool}>
          <h5 className="font-medium text-sm">Résultats de {tool}</h5>
          <pre className="bg-gray-100 p-2 rounded text-xs overflow-auto mt-1">
            {results.tools[tool].stdout}
          </pre>
          {results.tools[tool].stderr && (
            <pre className="bg-gray-200 p-2 rounded text-xs overflow-auto mt-1 text-red-600">
              {results.tools[tool].stderr}
            </pre>
          )}
        </div>
      ))}
    </div>
  );
}

// VncSession renommé en TerminalSession et modifié pour utiliser shellinabox
function TerminalSession({ fileId }) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [connectionInfo, setConnectionInfo] = useState(null);
  
  useEffect(() => {
    let mounted = true;
    const checkStatus = async () => {
      try {
        const response = await axios.get(`${API_URL}/files/${fileId}/vnc`);
        if (mounted) {
          setConnectionInfo(response.data);
          if (response.data.status === 'running') {
            setLoading(false);
          } else if (response.data.status === 'error') {
            setError(response.data.message || 'Erreur lors du démarrage de la session');
            setLoading(false);
          } else {
            // Si toujours en démarrage, vérifier à nouveau dans 2 secondes
            setTimeout(checkStatus, 2000);
          }
        }
      } catch (error) {
        if (mounted) {
          setError(`Erreur lors de la récupération des informations de connexion: ${error.message}`);
          setLoading(false);
        }
      }
    };
    
    checkStatus();
    
    return () => {
      mounted = false;
    };
  }, [fileId]);
  
  if (loading) {
    return (
      <div className="p-4 bg-gray-100 rounded text-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-800 mx-auto mb-2"></div>
        <p>Démarrage de la session interactive...</p>
      </div>
    );
  }
  
  if (error) {
    return (
      <div className="p-4 bg-red-50 text-red-700 rounded border border-red-200">
        <h4 className="font-semibold">Erreur</h4>
        <p>{error}</p>
      </div>
    );
  }
  
  return (
    <div>
      <div className="bg-black rounded-md overflow-hidden h-96 flex flex-col">
        <div className="bg-gray-800 text-gray-200 p-2 text-sm flex justify-between">
          <span>Terminal interactif</span>
          <a 
            href={`http://${window.location.hostname}:4200/`} 
            target="_blank" 
            rel="noopener noreferrer" 
            className="text-blue-400 hover:text-blue-300"
          >
            Ouvrir dans un nouvel onglet
          </a>
        </div>
        <iframe 
          src={`http://${window.location.hostname}:4200/`}
          className="flex-1 w-full"
          style={{ border: 'none' }}
          title="Terminal interactif"
        />
      </div>
      <div className="mt-2 text-sm text-gray-600">
        <p>
          Ce terminal vous permet d'exécuter des commandes shell dans l'environnement d'analyse.
        </p>
      </div>
    </div>
  );
}

// Ajoutez ce bouton à votre dashboard principal
function StartInteractiveButton() {
  const [sessionId, setSessionId] = useState(null);
  
  const startSessionMutation = useMutation(
    () => axios.post(`${API_URL}/interactive`),
    {
      onSuccess: (data) => {
        queryClient.invalidateQueries('analyses');
        setSessionId(data.data.id);
      }
    }
  );
  
  if (sessionId) {
    return (
      <div className="p-4 bg-white rounded shadow mb-4">
        <TerminalSession fileId={sessionId} />
      </div>
    );
  }
  
  return (
    <div className="p-4 bg-white rounded shadow mb-4">
      <h2 className="text-xl font-semibold mb-4">Session Interactive</h2>
      <button
        onClick={() => startSessionMutation.mutate()}
        disabled={startSessionMutation.isLoading}
        className={`w-full py-2 px-4 rounded ${
          startSessionMutation.isLoading
            ? 'bg-gray-300 cursor-not-allowed'
            : 'bg-indigo-600 hover:bg-indigo-700 text-white'
        }`}
      >
        {startSessionMutation.isLoading ? 'Démarrage en cours...' : 'Démarrer une session interactive'}
      </button>
      <p className="text-sm text-gray-500 mt-2">
        Lancez une analyse dans un environnement Linux Mint avec interface graphique accessible via le navigateur.
      </p>
    </div>
  );
}

export default App; 