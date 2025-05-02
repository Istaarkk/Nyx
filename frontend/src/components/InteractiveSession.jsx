import React, { useState, useEffect } from 'react';
import { Box, CircularProgress, Typography, Paper } from '@mui/material';
import { useParams } from 'react-router-dom';
import axios from 'axios';

const InteractiveSession = () => {
  const { id } = useParams();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [sessionInfo, setSessionInfo] = useState(null);

  useEffect(() => {
    const checkSessionStatus = async () => {
      try {
        const response = await axios.get(`http://localhost:8000/files/${id}/vnc`);
        setSessionInfo(response.data);
        
        if (response.data.status === 'running') {
          setLoading(false);
        } else if (response.data.status === 'error') {
          setError(response.data.message || 'Erreur lors du démarrage de la session interactive');
          setLoading(false);
        } else {
          // Si toujours en démarrage, vérifier à nouveau dans 2 secondes
          setTimeout(checkSessionStatus, 2000);
        }
      } catch (err) {
        setError('Erreur lors de la récupération des informations de la session');
        setLoading(false);
      }
    };

    checkSessionStatus();
  }, [id]);

  if (loading) {
    return (
      <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'center', mt: 4 }}>
        <CircularProgress />
        <Typography variant="h6" sx={{ mt: 2 }}>
          Démarrage de la session interactive...
        </Typography>
      </Box>
    );
  }

  if (error) {
    return (
      <Box sx={{ mt: 4, p: 2, bgcolor: '#ffebee', borderRadius: 1 }}>
        <Typography variant="h6" color="error">
          Erreur
        </Typography>
        <Typography>{error}</Typography>
      </Box>
    );
  }

  return (
    <Box sx={{ mt: 2 }}>
      <Typography variant="h5" gutterBottom>
        Session interactive
      </Typography>
      
      <Paper elevation={3} sx={{ p: 1, mt: 2, backgroundColor: '#000', height: '600px' }}>
        <iframe 
          src={`http://${window.location.hostname}:4200/`}
          style={{ 
            width: '100%', 
            height: '100%', 
            border: 'none',
            backgroundColor: '#000'
          }}
          title="Terminal Interactif"
        />
      </Paper>
      
      <Typography variant="body2" sx={{ mt: 2, color: 'text.secondary' }}>
        Cette session interactive vous permet d'exécuter des commandes directement dans l'environnement d'analyse.
      </Typography>
    </Box>
  );
};

export default InteractiveSession; 