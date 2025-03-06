import React, { useEffect, useState } from "react";
import { useParams } from "react-router-dom";

const API_URL = "https://www.omdbapi.com?apikey=cf20b56c";

const MovieDetails = () => {
  const { id } = useParams();
  const [movie, setMovie] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [trailerUrl, setTrailerUrl] = useState(""); // Define trailerUrl state

  useEffect(() => {
    const fetchMovieDetails = async () => {
      try {
        setLoading(true);
        const response = await fetch(`${API_URL}&i=${id}`);
        const data = await response.json();

        if (data.Response === "False") {
          setError("Movie not found");
        } else {
          setMovie(data);
          // Fetch trailer when movie details are fetched
          fetchTrailer(data.Title);
        }
      } catch (err) {
        setError("Failed to fetch movie details");
      } finally {
        setLoading(false);
      }
    };

    fetchMovieDetails();
  }, [id]);

  // Fetch trailer from YouTube using YouTube Search API
  const fetchTrailer = async (title) => {
    try {
      const searchQuery = `${title} official trailer`;
      const response = await fetch(
        `https://www.googleapis.com/youtube/v3/search?part=snippet&q=${encodeURIComponent(
          searchQuery
        )}&key=AIzaSyBGeuzO1AN0JaSBMDWqlKO9dr668PMudi0&type=video`
      );
      const data = await response.json();

      if (data.items.length > 0) {
        setTrailerUrl(`https://www.youtube.com/watch?v=${data.items[0].id.videoId}`);
      }
    } catch (err) {
      console.error("Failed to fetch trailer:", err);
    }
  };

  if (loading) {
    return <h2>Loading...</h2>;
  }

  if (error) {
    return <h2>{error}</h2>;
  }

  return (
    <div className="movie-details-container">
      <div className="movie-poster">
        <img src={movie.Poster} alt={movie.Title} />
      </div>
      <div className="movie-info">
        <h1 className="movie-title">{movie.Title}</h1>
        <p className="movie-meta">
          {movie.Year} • {movie.Runtime} • {movie.imdbRating}
        </p>
        <div className="genre-tags">
          {movie.Genre.split(", ").map((genre, index) => (
            <span key={index} className="genre-tag">
              {genre}
            </span>
          ))}
        </div>
        <p className="movie-description">{movie.Plot}</p>
        {trailerUrl ? (
          <button className="trailer-button" onClick={() => window.open(trailerUrl, "_blank")}>
            Play Trailer
          </button>
        ) : (
          <p>No trailer available</p>
        )}
      </div>
    </div>
  );
};

export default MovieDetails;
