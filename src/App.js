import React, { useState, useEffect } from "react";
import { BrowserRouter as Router, Route, Routes } from "react-router-dom";

import MovieCard from "./MovieCard";
import MovieDetails from "./MovieDetails"; // Import the new page
import SearchIcon from "./search.svg";
import "./App.css";

const API_URL = "http://www.omdbapi.com?apikey=cf20b56c";

const App = () => {
  const [searchTerm, setSearchTerm] = useState("");
  const [movies, setMovies] = useState([]);

  useEffect(() => {
    searchMovies("Avengers");
  }, []);

  const searchMovies = async (title) => {
    const response = await fetch(`${API_URL}&s=${title}`);
    const data = await response.json();

    setMovies(data.Search || []);
  };

  return (
    <Router>
      <div className="app">
        <h1>CodeTMA Movies.</h1>
        
        <Routes>
          <Route
            path="/"
            element={
              <>
                <div className="search">
                  <input
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    placeholder="Search for movies"
                  />
                  <img
                    src={SearchIcon}
                    alt="search"
                    onClick={() => searchMovies(searchTerm)}
                  />
                </div>

                {movies.length > 0 ? (
                  <div className="container">
                    {movies.map((movie) => (
                      <MovieCard key={movie.imdbID} movie={movie} />
                    ))}
                  </div>
                ) : (
                  <div className="empty">
                    <h2>No movies found</h2>
                  </div>
                )}
              </>
            }
          />
          <Route path="/movie/:id" element={<MovieDetails />} />
        </Routes>
      </div>
    </Router>
  );
};

export default App;
