"""
Matrix processor implementation that uses centralized configuration.

This module demonstrates how to use the centralized configuration system
instead of directly accessing environment variables.
"""

import logging
from typing import List, Any
from dataclasses import dataclass
from .config_loader import Config, get_config


@dataclass
class Matrix:
    """Represents a matrix with data and metadata."""
    data: List[List[float]]
    rows: int
    cols: int


class MatrixProcessor:
    """
    Processes matrices using parallel computation with centralized configuration.
    
    This class demonstrates proper usage of the centralized configuration system.
    All configuration values are accessed through the Config object rather than
    directly from environment variables.
    """
    
    def __init__(self, config: Config):
        """
        Initialize the matrix processor with configuration.
        
        Args:
            config: Centralized configuration object containing all settings
        """
        self._config = config
        self._logger = self._setup_logging()
    
    def _setup_logging(self) -> logging.Logger:
        """
        Set up logging using configuration settings.
        
        Returns:
            Configured logger instance
        """
        logger = logging.getLogger(__name__)
        
        # Configure logging level from config (not from ENV directly)
        level = getattr(logging, self._config.logging.level.upper())
        logger.setLevel(level)
        
        # Configure log format from config
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(self._config.logging.format)
            handler.setFormatter(formatter)
            logger.addHandler(handler)
        
        return logger
    
    def validate_matrix_size(self, matrix: Matrix) -> bool:
        """
        Validate matrix size against configuration limits.
        
        Args:
            matrix: Matrix to validate
            
        Returns:
            True if matrix size is within limits, False otherwise
        """
        total_elements = matrix.rows * matrix.cols
        max_size = self._config.matrix.max_size
        
        if total_elements > max_size:
            self._logger.warning(
                f"Matrix size {total_elements} exceeds maximum allowed size {max_size}"
            )
            return False
        
        return True
    
    def format_matrix(self, matrix: Matrix) -> str:
        """
        Format matrix according to configuration settings.
        
        Args:
            matrix: Matrix to format
            
        Returns:
            Formatted matrix string
        """
        if not self.validate_matrix_size(matrix):
            raise ValueError("Matrix size exceeds configuration limits")
        
        # Use precision from config
        precision = self._config.matrix.default_precision
        
        # Format according to output configuration
        output_format = self._config.output.format.lower()
        
        if output_format == "json":
            return self._format_as_json(matrix, precision)
        elif output_format == "csv":
            return self._format_as_csv(matrix, precision)
        else:
            raise ValueError(f"Unsupported output format: {output_format}")
    
    def _format_as_json(self, matrix: Matrix, precision: int) -> str:
        """
        Format matrix as JSON.
        
        Args:
            matrix: Matrix to format
            precision: Number of decimal places
            
        Returns:
            JSON formatted string
        """
        import json
        
        # Round values to specified precision
        rounded_data = [
            [round(val, precision) for val in row]
            for row in matrix.data
        ]
        
        result = {
            "matrix": rounded_data,
            "rows": matrix.rows,
            "cols": matrix.cols,
            "format": "json"
        }
        
        return json.dumps(result, indent=2)
    
    def _format_as_csv(self, matrix: Matrix, precision: int) -> str:
        """
        Format matrix as CSV.
        
        Args:
            matrix: Matrix to format
            precision: Number of decimal places
            
        Returns:
            CSV formatted string
        """
        import csv
        import io
        
        output = io.StringIO()
        writer = csv.writer(output)
        
        # Write matrix data with specified precision
        for row in matrix.data:
            rounded_row = [round(val, precision) for val in row]
            writer.writerow(rounded_row)
        
        return output.getvalue()


class ParallelMatrixFormatter:
    """
    Main formatter class that coordinates parallel matrix processing.
    
    This class demonstrates how multiple components can share the same
    centralized configuration object.
    """
    
    def __init__(self, config: Config):
        """
        Initialize the parallel matrix formatter.
        
        Args:
            config: Centralized configuration object
        """
        self._config = config
        self._processor = MatrixProcessor(config)
        self._logger = self._setup_logging()
    
    def _setup_logging(self) -> logging.Logger:
        """
        Set up logging for the formatter.
        
        Returns:
            Configured logger instance
        """
        logger = logging.getLogger(__name__ + ".ParallelMatrixFormatter")
        level = getattr(logging, self._config.logging.level.upper())
        logger.setLevel(level)
        
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(self._config.logging.format)
            handler.setFormatter(formatter)
            logger.addHandler(handler)
        
        return logger
    
    def process_matrices(self, matrices: List[Matrix]) -> List[str]:
        """
        Process multiple matrices using parallel configuration.
        
        Args:
            matrices: List of matrices to process
            
        Returns:
            List of formatted matrix strings
        """
        num_workers = self._config.parallel.workers
        chunk_size = self._config.parallel.chunk_size
        
        self._logger.info(
            f"Processing {len(matrices)} matrices with {num_workers} workers, "
            f"chunk size: {chunk_size}"
        )
        
        # For this example, we'll simulate parallel processing
        # In a real implementation, this would use multiprocessing or threading
        results = []
        
        for i, matrix in enumerate(matrices):
            try:
                formatted = self._processor.format_matrix(matrix)
                results.append(formatted)
                
                if self._config.debug.enabled:
                    self._logger.debug(f"Processed matrix {i+1}/{len(matrices)}")
                    
            except Exception as e:
                self._logger.error(f"Failed to process matrix {i+1}: {e}")
                results.append(f"Error: {str(e)}")
        
        return results


def create_formatter() -> ParallelMatrixFormatter:
    """
    Factory function to create a ParallelMatrixFormatter with centralized config.
    
    This function demonstrates the recommended pattern for creating components
    that need configuration. Instead of each component loading its own config,
    the centralized config is loaded once and passed to all components.
    
    Returns:
        Configured ParallelMatrixFormatter instance
    """
    # Load centralized configuration
    config = get_config()
    
    # Create formatter with the config
    return ParallelMatrixFormatter(config)